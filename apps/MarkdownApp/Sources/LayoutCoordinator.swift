import Foundation
import MarkdownCore
import MarkdownParse
import MarkdownLayout
import MarkdownRender
import MarkdownPerf

// MARK: - LayoutCoordinator

/// Central coordinator that manages the edit → parse → layout → preview pipeline.
///
/// Responsibilities:
/// - Accept edit events from the editor (main thread)
/// - Coalesce edits into a dirty region
/// - Dispatch background pipeline work (cancelable)
/// - Apply preview diffs back on the main thread (revision-guarded)
///
/// Concurrency model:
/// - Edit recording happens on the main thread (synchronous, fast)
/// - Pipeline work runs on a background Task (last-write-wins: new edits cancel in-flight work)
/// - Preview apply dispatches back to main thread, guarded by revision
final class LayoutCoordinator {
    // MARK: - State

    /// Current document revision. Incremented on every edit.
    private var currentRevision: Int = 0

    /// The dirty tracker coalescing edits since last pipeline run.
    private var dirtyTracker = DirtyTracker()

    /// The current line index, updated incrementally on each edit.
    private var lineIndex = LineIndex()

    /// The block index (ordered blocks + layouts).
    private var blockIndex = BlockIndex()

    /// The block ID generator.
    private let idGenerator = BlockIDGenerator()

    /// The parser.
    private let parser: any MarkdownParser

    /// The block differ.
    private let differ = BlockDiffer()

    /// The block builder (post-processes parse output).
    private let blockBuilder = BlockBuilder()

    /// The layout engine.
    private let layoutEngine = LayoutEngine()

    /// The layout cache.
    private var layoutCache = LayoutCache()

    /// The preview diff builder.
    private let diffBuilder = PreviewDiffBuilder()

    /// Performance counters for the HUD.
    let perfCounters = PerfCounters()

    /// The current theme.
    var theme: ThemeStyle = .light

    /// The in-flight background task. Canceled when a new edit arrives.
    private var activeTask: Task<Void, Never>?

    /// Debounce interval for pipeline dispatch (seconds).
    private let debounceInterval: TimeInterval = 0.016 // ~60 Hz

    // MARK: - UI References

    private weak var editorViewController: EditorViewController?
    private weak var previewViewController: PreviewViewController?

    // MARK: - Init

    init(
        editorViewController: EditorViewController,
        previewViewController: PreviewViewController,
        parser: any MarkdownParser = CmarkParser()
    ) {
        self.editorViewController = editorViewController
        self.previewViewController = previewViewController
        self.parser = parser
    }

    // MARK: - Edit Recording (Main Thread)

    /// Called from EditorViewController's text storage delegate.
    /// This is the HOT PATH. Must be fast and synchronous.
    func recordEdit(editedRange: NSRange, changeInLength: Int, currentText: NSString) {
        MarkdownSignpost.beginEditCapture()

        currentRevision += 1
        perfCounters.recordRevision(currentRevision)

        // Update line index incrementally
        lineIndex.update(editedRange: editedRange, changeInLength: changeInLength, newText: currentText)

        // Record the dirty range
        dirtyTracker.recordEdit(editedRange: editedRange, changeInLength: changeInLength)
        perfCounters.recordDirtyRange(size: dirtyTracker.dirtyRange?.length ?? 0)

        MarkdownSignpost.endEditCapture()

        // Schedule background pipeline (cancels previous)
        schedulePipeline(text: currentText)
    }

    /// Called when a file is first loaded. Full parse, no incremental.
    func documentDidLoad(text: NSString) {
        currentRevision += 1
        lineIndex = LineIndex(text: text)

        let snapshot = DocumentSnapshot(text: text, revision: currentRevision, lineIndex: lineIndex)

        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.runFullParse(snapshot: snapshot)
        }
    }

    // MARK: - Pipeline Dispatch

    private func schedulePipeline(text: NSString) {
        // Cancel any in-flight work
        activeTask?.cancel()

        let snapshot = DocumentSnapshot(text: text, revision: currentRevision, lineIndex: lineIndex)
        let dirtyTrackerCopy = dirtyTracker
        dirtyTracker.reset()

        activeTask = Task { [weak self] in
            guard let self else { return }

            // Small debounce to coalesce rapid typing
            try? await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await self.runIncrementalPipeline(
                snapshot: snapshot,
                dirtyTracker: dirtyTrackerCopy
            )
        }
    }

    // MARK: - Full Parse Pipeline

    private func runFullParse(snapshot: DocumentSnapshot) async {
        let parseTimeMicros = measureMicroseconds {
            let blocks = parser.parseFullDocument(text: snapshot.text, idGenerator: idGenerator)
            let built = blockBuilder.build(blocks: blocks, snapshot: snapshot, regionRange: NSRange(location: 0, length: snapshot.length))
            blockIndex.replaceAll(blocks: built)
        }
        perfCounters.recordParseTime(microseconds: parseTimeMicros)
        perfCounters.recordTotalBlocks(blockIndex.blocks.count)

        guard !Task.isCancelled else { return }

        // Layout all blocks
        let width = await MainActor.run { previewViewController?.availableWidth ?? 600 }

        let layoutTimeMicros = measureMicroseconds {
            let _ = layoutEngine.layoutBlocks(blockIndex.blocks, width: width, theme: theme, cache: &layoutCache)
        }
        perfCounters.recordLayoutTime(microseconds: layoutTimeMicros)

        guard !Task.isCancelled else { return }

        // Build full layout blocks for initial display
        let layouts = blockIndex.blocks.compactMap { block -> LayoutBlock? in
            let key = LayoutKey(blockID: block.id, width: width, themeVariant: theme.variant, contentHash: block.contentHash)
            return layoutCache.get(key: key)
        }

        // Apply on main thread if revision still matches
        let revision = snapshot.revision
        await MainActor.run { [weak self] in
            guard let self, self.currentRevision == revision else { return }
            MarkdownSignpost.beginPreviewApply()
            self.previewViewController?.renderer?.replaceAll(layouts: layouts)
            MarkdownSignpost.endPreviewApply()
        }
    }

    // MARK: - Incremental Pipeline

    private func runIncrementalPipeline(
        snapshot: DocumentSnapshot,
        dirtyTracker: DirtyTracker
    ) async {
        // 1. Compute safe reparse region
        MarkdownSignpost.beginDirtyExpand()
        guard let reparseRegion = dirtyTracker.safeReparseRegion(in: snapshot) else {
            MarkdownSignpost.endDirtyExpand()
            return
        }
        MarkdownSignpost.endDirtyExpand()
        perfCounters.recordReparseRegion(size: reparseRegion.length)

        guard !Task.isCancelled else { return }

        // 2. Parse the reparse region
        MarkdownSignpost.beginParse()
        let rawBlocks = parser.parse(text: snapshot.text, range: reparseRegion, idGenerator: idGenerator)
        let newBlocks = blockBuilder.build(blocks: rawBlocks, snapshot: snapshot, regionRange: reparseRegion)
        MarkdownSignpost.endParse()

        guard !Task.isCancelled else { return }

        // 3. Find old blocks in the reparse region and diff
        MarkdownSignpost.beginBlockDiff()
        let oldBlocks = blockIndex.blocks.filter { block in
            let blockEnd = NSMaxRange(block.range)
            let regionEnd = NSMaxRange(reparseRegion)
            return block.range.location < regionEnd && blockEnd > reparseRegion.location
        }
        let diff = differ.diff(
            oldBlocks: oldBlocks,
            newBlocks: newBlocks,
            changeInLength: dirtyTracker.accumulatedDelta
        )
        MarkdownSignpost.endBlockDiff()
        perfCounters.recordBlocksChanged(diff.insertedBlocks.count + diff.updatedBlocks.count + diff.removedIDs.count)

        guard !Task.isCancelled, !diff.isEmpty else { return }

        // 4. Layout changed blocks
        MarkdownSignpost.beginLayout()
        let width = await MainActor.run { previewViewController?.availableWidth ?? 600 }

        let blocksToLayout = diff.insertedBlocks + diff.updatedBlocks
        let layoutBlocks = layoutEngine.layoutBlocks(blocksToLayout, width: width, theme: theme, cache: &layoutCache)
        var layoutMap: [BlockID: LayoutBlock] = [:]
        for lb in layoutBlocks {
            layoutMap[lb.id] = lb
        }
        MarkdownSignpost.endLayout()

        guard !Task.isCancelled else { return }

        // 5. Apply block index updates
        // Remove old blocks, insert new ones, shift ranges
        var updatedBlocks = blockIndex.blocks.filter { !diff.removedIDs.contains($0.id) }
        // Update ranges for blocks after the reparse region
        for i in 0..<updatedBlocks.count {
            if updatedBlocks[i].range.location >= NSMaxRange(reparseRegion) - diff.rangeShiftDelta {
                updatedBlocks[i].range.location += diff.rangeShiftDelta
            }
        }
        // Replace blocks in the reparse region with new ones
        updatedBlocks.removeAll { block in
            diff.updatedBlocks.contains(where: { $0.id == block.id })
        }
        updatedBlocks.append(contentsOf: diff.insertedBlocks)
        updatedBlocks.append(contentsOf: diff.updatedBlocks)
        updatedBlocks.sort { $0.range.location < $1.range.location }
        blockIndex.replaceAll(blocks: updatedBlocks)
        perfCounters.recordTotalBlocks(blockIndex.blocks.count)

        // 6. Build preview diff
        let allBlockIDs = blockIndex.blocks.map(\.id)
        let previewDiff = diffBuilder.build(
            blockDiff: diff,
            newLayouts: layoutMap,
            allBlockIDs: allBlockIDs,
            revision: snapshot.revision
        )

        // 7. Apply on main thread (revision-guarded)
        let revision = snapshot.revision
        await MainActor.run { [weak self] in
            guard let self, self.currentRevision == revision else { return }
            MarkdownSignpost.beginPreviewApply()
            let applyTime = measureMicroseconds {
                self.previewViewController?.renderer?.apply(diff: previewDiff)
            }
            self.perfCounters.recordApplyTime(microseconds: applyTime)
            MarkdownSignpost.endPreviewApply()
        }
    }
}
