import Foundation

// MARK: - LineIndex

/// Maintains an array of line-start offsets in UTF-16 units.
///
/// This supports fast operations:
/// - Expand an edit range to whole lines
/// - Map between line numbers and UTF-16 offsets
/// - Find block boundaries by scanning nearby lines
///
/// The index is incrementally updated on each edit — it never rescans the whole file.
public struct LineIndex: Sendable {
    /// Sorted array of UTF-16 offsets where each line starts.
    /// `lineStarts[0]` is always 0. `lineStarts[i]` is the offset of the first
    /// character on line `i`.
    public private(set) var lineStarts: [Int]

    /// Total length of the text in UTF-16 units.
    public private(set) var textLength: Int

    // MARK: - Init

    /// Build a `LineIndex` by scanning the full text once.
    public init(text: NSString) {
        var starts = [0]
        let length = text.length
        var i = 0
        while i < length {
            let ch = text.character(at: i)
            i += 1
            if ch == 0x0A { // \n
                starts.append(i)
            } else if ch == 0x0D { // \r
                if i < length && text.character(at: i) == 0x0A {
                    i += 1 // skip \r\n as one line break
                }
                starts.append(i)
            }
        }
        self.lineStarts = starts
        self.textLength = length
    }

    /// Create an empty `LineIndex`.
    public init() {
        self.lineStarts = [0]
        self.textLength = 0
    }

    // MARK: - Queries

    /// Number of lines in the document.
    public var lineCount: Int { lineStarts.count }

    /// Returns the line number (0-based) containing the given UTF-16 offset.
    /// Uses binary search — O(log n).
    public func lineNumber(for offset: Int) -> Int {
        precondition(offset >= 0 && offset <= textLength, "Offset \(offset) out of bounds")
        // Binary search for the largest lineStart <= offset
        var lo = 0
        var hi = lineStarts.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if lineStarts[mid] <= offset {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo - 1
    }

    /// Returns the UTF-16 range for the given line (0-based).
    /// The range includes the trailing newline if present.
    public func lineRange(forLine line: Int) -> NSRange {
        precondition(line >= 0 && line < lineStarts.count, "Line \(line) out of bounds")
        let start = lineStarts[line]
        let end: Int
        if line + 1 < lineStarts.count {
            end = lineStarts[line + 1]
        } else {
            end = textLength
        }
        return NSRange(location: start, length: end - start)
    }

    /// Expands the given range to encompass full lines.
    public func expandToFullLines(_ range: NSRange) -> NSRange {
        guard range.length > 0 || range.location < textLength else {
            return range
        }
        let startLine = lineNumber(for: range.location)
        let endOffset = min(NSMaxRange(range), textLength)
        let endLine: Int
        if endOffset == 0 {
            endLine = 0
        } else if endOffset == textLength {
            endLine = lineStarts.count - 1
        } else {
            endLine = lineNumber(for: endOffset)
        }
        let expandedStart = lineStarts[startLine]
        let expandedEnd: Int
        if endLine + 1 < lineStarts.count {
            expandedEnd = lineStarts[endLine + 1]
        } else {
            expandedEnd = textLength
        }
        return NSRange(location: expandedStart, length: expandedEnd - expandedStart)
    }

    // MARK: - Incremental Update

    /// Update the line index after an edit.
    ///
    /// - Parameters:
    ///   - editedRange: The range in the *old* text that was replaced.
    ///   - changeInLength: `newLength - oldLength` for the edit.
    ///   - newText: The full new text (needed to scan the edited region for newlines).
    public mutating func update(editedRange: NSRange, changeInLength: Int, newText: NSString) {
        let oldEnd = NSMaxRange(editedRange)
        let newEnd = editedRange.location + editedRange.length + changeInLength

        // Find which lines are affected
        let firstAffectedLine = lineNumber(for: editedRange.location)
        var lastAffectedLine = firstAffectedLine
        while lastAffectedLine + 1 < lineStarts.count && lineStarts[lastAffectedLine + 1] <= oldEnd {
            lastAffectedLine += 1
        }

        // Scan the replacement region in the new text for line starts
        var newLineStarts: [Int] = []
        let scanStart = editedRange.location
        let scanEnd = newEnd
        var i = scanStart
        while i < scanEnd {
            let ch = newText.character(at: i)
            i += 1
            if ch == 0x0A { // \n
                newLineStarts.append(i)
            } else if ch == 0x0D { // \r
                if i < scanEnd && newText.character(at: i) == 0x0A {
                    i += 1
                }
                newLineStarts.append(i)
            }
        }

        // Replace affected line starts with new ones
        let replaceStart = firstAffectedLine + 1
        let replaceEnd = lastAffectedLine + 1
        lineStarts.replaceSubrange(replaceStart..<replaceEnd, with: newLineStarts)

        // Shift all line starts after the edited region by changeInLength
        let shiftStart = replaceStart + newLineStarts.count
        for idx in shiftStart..<lineStarts.count {
            lineStarts[idx] += changeInLength
        }

        textLength += changeInLength
    }
}
