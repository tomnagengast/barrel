import Foundation
import MarkdownCore
import MarkdownLayout

#if canImport(AppKit)
import AppKit
#endif

// MARK: - PreviewRenderer

/// Protocol for preview rendering backends.
///
/// Implementations take a `PreviewDiff` and apply it to their backing view.
/// The protocol allows swapping between TextKit and CoreText backends.
public protocol PreviewRenderer: AnyObject {
    /// Apply a preview diff. Called on the main thread.
    /// - Parameter diff: The diff to apply.
    func apply(diff: PreviewDiff)

    /// Replace the entire preview with a fresh set of layout blocks.
    /// Used on initial load or when incremental update is not possible.
    func replaceAll(layouts: [LayoutBlock])

    /// Clear the preview entirely.
    func clear()
}

#if canImport(AppKit)

// MARK: - TextKitPreviewRenderer

/// Stage 1 preview renderer using a read-only `NSTextView`.
///
/// Splices attributed strings at the block level — does not rebuild
/// the entire text storage on each update.
public final class TextKitPreviewRenderer: PreviewRenderer {
    /// The text storage backing the preview text view.
    private let textStorage: NSTextStorage

    /// Ordered list of block IDs currently in the text storage.
    private var blockOrder: [BlockID] = []

    /// Map from block ID to its current range in the text storage.
    private var blockRanges: [BlockID: NSRange] = [:]

    /// Map from block ID to its layout block.
    private var layouts: [BlockID: LayoutBlock] = [:]

    public init(textStorage: NSTextStorage) {
        self.textStorage = textStorage
    }

    public func apply(diff: PreviewDiff) {
        textStorage.beginEditing()

        // 1. Remove blocks (process in reverse order to preserve ranges)
        let removedIndices = blockOrder.enumerated()
            .filter { diff.removedIDs.contains($0.element) }
            .map(\.offset)
            .sorted(by: >)

        for idx in removedIndices {
            let blockID = blockOrder[idx]
            if let range = blockRanges[blockID] {
                textStorage.deleteCharacters(in: range)
                // Shift subsequent block ranges
                shiftRanges(after: range.location, by: -range.length)
            }
            blockOrder.remove(at: idx)
            blockRanges.removeValue(forKey: blockID)
            layouts.removeValue(forKey: blockID)
        }

        // 2. Insert new blocks
        for (index, layout) in diff.insertedLayouts.sorted(by: { $0.index < $1.index }) {
            let attrString = extractAttributedString(from: layout)
            let insertionPoint: Int
            if index > 0 && index - 1 < blockOrder.count {
                let prevID = blockOrder[index - 1]
                let prevRange = blockRanges[prevID] ?? NSRange(location: 0, length: 0)
                insertionPoint = NSMaxRange(prevRange)
            } else if index == 0 {
                insertionPoint = 0
            } else {
                insertionPoint = textStorage.length
            }

            textStorage.insert(attrString, at: insertionPoint)

            let insertedRange = NSRange(location: insertionPoint, length: attrString.length)
            shiftRanges(after: insertionPoint, by: attrString.length)

            let safeIndex = min(index, blockOrder.count)
            blockOrder.insert(layout.id, at: safeIndex)
            blockRanges[layout.id] = insertedRange
            layouts[layout.id] = layout
        }

        // 3. Update existing blocks
        for layout in diff.updatedLayouts {
            guard let existingRange = blockRanges[layout.id] else { continue }
            let attrString = extractAttributedString(from: layout)
            let lengthDelta = attrString.length - existingRange.length

            textStorage.replaceCharacters(in: existingRange, with: attrString)

            blockRanges[layout.id] = NSRange(location: existingRange.location, length: attrString.length)
            shiftRanges(after: NSMaxRange(existingRange), by: lengthDelta)
            layouts[layout.id] = layout
        }

        textStorage.endEditing()
    }

    public func replaceAll(layouts newLayouts: [LayoutBlock]) {
        textStorage.beginEditing()
        textStorage.deleteCharacters(in: NSRange(location: 0, length: textStorage.length))

        blockOrder = []
        blockRanges = [:]
        layouts = [:]

        var offset = 0
        for layout in newLayouts {
            let attrString = extractAttributedString(from: layout)
            textStorage.insert(attrString, at: offset)
            let range = NSRange(location: offset, length: attrString.length)
            blockOrder.append(layout.id)
            blockRanges[layout.id] = range
            layouts[layout.id] = layout
            offset += attrString.length
        }

        textStorage.endEditing()
    }

    public func clear() {
        textStorage.beginEditing()
        textStorage.deleteCharacters(in: NSRange(location: 0, length: textStorage.length))
        textStorage.endEditing()
        blockOrder = []
        blockRanges = [:]
        layouts = [:]
    }

    // MARK: - Private

    private func extractAttributedString(from layout: LayoutBlock) -> NSAttributedString {
        switch layout.drawPayload {
        case .attributedString(let attrStr):
            // Append a newline separator between blocks
            let mutable = NSMutableAttributedString(attributedString: attrStr)
            mutable.append(NSAttributedString(string: "\n"))
            return mutable
        case .coreTextPlaceholder, .none:
            return NSAttributedString(string: "\n")
        }
    }

    private func shiftRanges(after offset: Int, by delta: Int) {
        for (blockID, range) in blockRanges {
            if range.location >= offset {
                blockRanges[blockID] = NSRange(location: range.location + delta, length: range.length)
            }
        }
    }
}

#endif
