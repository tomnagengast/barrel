import Foundation

// MARK: - DirtyTracker

/// Coalesces document edits into a minimal set of dirty ranges and expands
/// them to safe reparse regions.
///
/// Usage:
/// 1. Call `recordEdit` for each `NSTextStorage` edit.
/// 2. Call `safeReparseRegion` to get the expanded region for reparsing.
/// 3. Call `reset` after the reparse is dispatched.
public struct DirtyTracker: Sendable {
    /// The coalesced dirty range, or `nil` if no edits have been recorded.
    public private(set) var dirtyRange: NSRange?

    /// Total accumulated change in length across all coalesced edits.
    public private(set) var accumulatedDelta: Int

    public init() {
        self.dirtyRange = nil
        self.accumulatedDelta = 0
    }

    // MARK: - Record

    /// Record an edit from `NSTextStorage.processEditing`.
    ///
    /// - Parameters:
    ///   - editedRange: The range in the *current* (post-edit) text that changed.
    ///   - changeInLength: The delta (`newLength - oldLength`).
    public mutating func recordEdit(editedRange: NSRange, changeInLength: Int) {
        accumulatedDelta += changeInLength
        if let existing = dirtyRange {
            dirtyRange = union(existing, editedRange)
        } else {
            dirtyRange = editedRange
        }
    }

    /// Merge two ranges into the smallest range containing both.
    private func union(_ a: NSRange, _ b: NSRange) -> NSRange {
        let start = min(a.location, b.location)
        let end = max(NSMaxRange(a), NSMaxRange(b))
        return NSRange(location: start, length: end - start)
    }

    // MARK: - Safe Reparse Region

    /// Compute a safe reparse region by expanding the dirty range to hard boundaries.
    ///
    /// Hard boundaries (lines where it is safe to start/stop a reparse):
    /// - Blank lines not inside a fenced code block
    /// - Lines starting with a heading marker (`#`)
    /// - Lines that are a thematic break (`---`, `***`, `___`)
    /// - Fence delimiters (``` or ~~~)
    ///
    /// - Parameters:
    ///   - snapshot: The current document snapshot (post-edit).
    ///   - safetyMargin: Extra lines to include above and below. Default is 3.
    /// - Returns: The expanded `NSRange` for reparsing, or `nil` if there is no dirty range.
    public func safeReparseRegion(
        in snapshot: DocumentSnapshot,
        safetyMargin: Int = 3
    ) -> NSRange? {
        guard let dirty = dirtyRange else { return nil }
        let lineIndex = snapshot.lineIndex

        // Expand to full lines first
        var region = lineIndex.expandToFullLines(dirty)

        // Find start and end lines
        let startLine = lineIndex.lineNumber(for: region.location)
        let endOffset = NSMaxRange(region)
        let endLine = endOffset >= snapshot.length
            ? lineIndex.lineCount - 1
            : lineIndex.lineNumber(for: min(endOffset, snapshot.length))

        // Expand upward to a hard boundary or safety margin
        let expandUp = expandToHardBoundary(
            from: startLine,
            direction: -1,
            maxSteps: safetyMargin,
            snapshot: snapshot,
            lineIndex: lineIndex
        )

        // Expand downward to a hard boundary or safety margin
        let expandDown = expandToHardBoundary(
            from: endLine,
            direction: 1,
            maxSteps: safetyMargin,
            snapshot: snapshot,
            lineIndex: lineIndex
        )

        let expandedStart = lineIndex.lineStarts[expandUp]
        let expandedEnd: Int
        if expandDown + 1 < lineIndex.lineCount {
            expandedEnd = lineIndex.lineStarts[expandDown + 1]
        } else {
            expandedEnd = snapshot.length
        }

        region = NSRange(location: expandedStart, length: expandedEnd - expandedStart)
        return region
    }

    /// Walk lines in the given direction looking for a hard boundary.
    /// Returns the line number to use as the boundary.
    private func expandToHardBoundary(
        from startLine: Int,
        direction: Int,
        maxSteps: Int,
        snapshot: DocumentSnapshot,
        lineIndex: LineIndex
    ) -> Int {
        var line = startLine
        var steps = 0

        while steps < maxSteps {
            let nextLine = line + direction
            if nextLine < 0 || nextLine >= lineIndex.lineCount {
                break
            }
            line = nextLine
            steps += 1

            if isHardBoundary(line: line, snapshot: snapshot, lineIndex: lineIndex) {
                break
            }
        }
        return line
    }

    /// Check if a line is a hard boundary where it's safe to start/stop parsing.
    private func isHardBoundary(
        line: Int,
        snapshot: DocumentSnapshot,
        lineIndex: LineIndex
    ) -> Bool {
        let range = lineIndex.lineRange(forLine: line)
        if range.length == 0 { return true } // empty line at end

        let lineText = snapshot.text.substring(with: range)
        let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Blank line
        if trimmed.isEmpty { return true }

        // Heading
        if trimmed.hasPrefix("#") { return true }

        // Thematic break (simplified check)
        if isThematicBreak(trimmed) { return true }

        // Fence delimiter
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { return true }

        return false
    }

    /// Check if trimmed line content is a thematic break.
    private func isThematicBreak(_ trimmed: String) -> Bool {
        let chars = Set(trimmed.filter { !$0.isWhitespace })
        if chars.count == 1, let ch = chars.first, ["-", "*", "_"].contains(ch) {
            let count = trimmed.filter { $0 == ch }.count
            return count >= 3
        }
        return false
    }

    // MARK: - Reset

    /// Clear the dirty state after dispatching a reparse.
    public mutating func reset() {
        dirtyRange = nil
        accumulatedDelta = 0
    }
}
