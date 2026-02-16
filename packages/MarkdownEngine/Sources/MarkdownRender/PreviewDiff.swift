import Foundation
import MarkdownCore
import MarkdownLayout
import MarkdownParse

// MARK: - PreviewDiff

/// A minimal diff to apply to the preview view.
///
/// Produced by the background pipeline, consumed by the main thread.
/// The main thread applies it only if `revision` matches the current document revision.
public struct PreviewDiff: Sendable {
    /// The document revision this diff was computed against.
    public let revision: Int

    /// Blocks that should be removed from the preview.
    public let removedIDs: [BlockID]

    /// New blocks to insert, with their position index in the block list.
    public let insertedLayouts: [(index: Int, layout: LayoutBlock)]

    /// Existing blocks whose layout changed (re-render in place).
    public let updatedLayouts: [LayoutBlock]

    /// The new complete ordered list of block IDs (for the preview to reorder).
    public let blockOrder: [BlockID]

    public init(
        revision: Int,
        removedIDs: [BlockID],
        insertedLayouts: [(index: Int, layout: LayoutBlock)],
        updatedLayouts: [LayoutBlock],
        blockOrder: [BlockID]
    ) {
        self.revision = revision
        self.removedIDs = removedIDs
        self.insertedLayouts = insertedLayouts
        self.updatedLayouts = updatedLayouts
        self.blockOrder = blockOrder
    }

    /// Whether this diff contains no changes.
    public var isEmpty: Bool {
        removedIDs.isEmpty && insertedLayouts.isEmpty && updatedLayouts.isEmpty
    }
}

// MARK: - PreviewDiffBuilder

/// Builds a `PreviewDiff` from a `BlockDiff` and layout results.
public struct PreviewDiffBuilder: Sendable {

    public init() {}

    /// Build a preview diff from a block diff and the new layout blocks.
    ///
    /// - Parameters:
    ///   - blockDiff: The structural diff (inserts, removes, updates).
    ///   - newLayouts: Layout results for inserted and updated blocks.
    ///   - allBlockIDs: The complete ordered list of block IDs after applying the diff.
    ///   - revision: The document revision.
    /// - Returns: A `PreviewDiff` ready for the main thread.
    public func build(
        blockDiff: BlockDiff,
        newLayouts: [BlockID: LayoutBlock],
        allBlockIDs: [BlockID],
        revision: Int
    ) -> PreviewDiff {
        var insertedLayouts: [(index: Int, layout: LayoutBlock)] = []
        for (index, blockID) in allBlockIDs.enumerated() {
            if let layout = newLayouts[blockID],
               blockDiff.insertedBlocks.contains(where: { $0.id == blockID }) {
                insertedLayouts.append((index: index, layout: layout))
            }
        }

        var updatedLayouts: [LayoutBlock] = []
        for block in blockDiff.updatedBlocks {
            if let layout = newLayouts[block.id] {
                updatedLayouts.append(layout)
            }
        }

        return PreviewDiff(
            revision: revision,
            removedIDs: blockDiff.removedIDs,
            insertedLayouts: insertedLayouts,
            updatedLayouts: updatedLayouts,
            blockOrder: allBlockIDs
        )
    }
}
