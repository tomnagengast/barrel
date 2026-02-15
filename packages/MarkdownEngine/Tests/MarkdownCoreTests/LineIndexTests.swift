import XCTest
@testable import MarkdownCore

final class LineIndexTests: XCTestCase {

    // MARK: - Init

    func test_lineIndex_emptyString_hasSingleLineStart() {
        let index = LineIndex(text: "" as NSString)
        XCTAssertEqual(index.lineCount, 1)
        XCTAssertEqual(index.lineStarts, [0])
        XCTAssertEqual(index.textLength, 0)
    }

    func test_lineIndex_singleLine_hasSingleLineStart() {
        let index = LineIndex(text: "hello" as NSString)
        XCTAssertEqual(index.lineCount, 1)
        XCTAssertEqual(index.lineStarts, [0])
        XCTAssertEqual(index.textLength, 5)
    }

    func test_lineIndex_multipleLines_correctStarts() {
        let text = "line1\nline2\nline3" as NSString
        let index = LineIndex(text: text)
        XCTAssertEqual(index.lineCount, 3)
        XCTAssertEqual(index.lineStarts, [0, 6, 12])
        XCTAssertEqual(index.textLength, 17)
    }

    func test_lineIndex_trailingNewline_addsEmptyLine() {
        let text = "line1\nline2\n" as NSString
        let index = LineIndex(text: text)
        XCTAssertEqual(index.lineCount, 3)
        XCTAssertEqual(index.lineStarts, [0, 6, 12])
    }

    func test_lineIndex_crlfLineBreaks_treatedAsSingle() {
        let text = "line1\r\nline2\r\nline3" as NSString
        let index = LineIndex(text: text)
        XCTAssertEqual(index.lineCount, 3)
        XCTAssertEqual(index.lineStarts, [0, 7, 14])
    }

    // MARK: - lineNumber(for:)

    func test_lineNumber_startOfLine_returnsCorrectLine() {
        let text = "aaa\nbbb\nccc" as NSString
        let index = LineIndex(text: text)
        XCTAssertEqual(index.lineNumber(for: 0), 0)
        XCTAssertEqual(index.lineNumber(for: 4), 1)
        XCTAssertEqual(index.lineNumber(for: 8), 2)
    }

    func test_lineNumber_middleOfLine_returnsCorrectLine() {
        let text = "aaa\nbbb\nccc" as NSString
        let index = LineIndex(text: text)
        XCTAssertEqual(index.lineNumber(for: 2), 0)
        XCTAssertEqual(index.lineNumber(for: 5), 1)
        XCTAssertEqual(index.lineNumber(for: 10), 2)
    }

    func test_lineNumber_atEnd_returnsLastLine() {
        let text = "aaa\nbbb" as NSString
        let index = LineIndex(text: text)
        XCTAssertEqual(index.lineNumber(for: 7), 1) // at textLength
    }

    // MARK: - lineRange(forLine:)

    func test_lineRange_firstLine_correctRange() {
        let text = "hello\nworld" as NSString
        let index = LineIndex(text: text)
        let range = index.lineRange(forLine: 0)
        XCTAssertEqual(range, NSRange(location: 0, length: 6)) // includes \n
    }

    func test_lineRange_lastLine_correctRange() {
        let text = "hello\nworld" as NSString
        let index = LineIndex(text: text)
        let range = index.lineRange(forLine: 1)
        XCTAssertEqual(range, NSRange(location: 6, length: 5))
    }

    // MARK: - expandToFullLines

    func test_expandToFullLines_midLine_expandsToFullLine() {
        let text = "aaa\nbbb\nccc" as NSString
        let index = LineIndex(text: text)
        // Range in middle of line 1
        let result = index.expandToFullLines(NSRange(location: 5, length: 1))
        XCTAssertEqual(result, NSRange(location: 4, length: 4)) // "bbb\n"
    }

    func test_expandToFullLines_spanningLines_expandsBoth() {
        let text = "aaa\nbbb\nccc" as NSString
        let index = LineIndex(text: text)
        // Range from mid line 0 to mid line 1
        let result = index.expandToFullLines(NSRange(location: 2, length: 4))
        XCTAssertEqual(result, NSRange(location: 0, length: 8)) // "aaa\nbbb\n"
    }

    // MARK: - Incremental Update

    func test_update_insertAtEnd_updatesCorrectly() {
        var index = LineIndex(text: "aaa\nbbb" as NSString)
        XCTAssertEqual(index.lineCount, 2)

        // Append "\nccc" at position 7
        let newText = "aaa\nbbb\nccc" as NSString
        index.update(editedRange: NSRange(location: 7, length: 0), changeInLength: 4, newText: newText)

        XCTAssertEqual(index.lineCount, 3)
        XCTAssertEqual(index.lineStarts, [0, 4, 8])
        XCTAssertEqual(index.textLength, 11)
    }

    func test_update_insertMiddle_shiftsSubsequentLines() {
        var index = LineIndex(text: "aa\nbb\ncc" as NSString)
        XCTAssertEqual(index.lineStarts, [0, 3, 6])

        // Insert "x" at position 4 (middle of line 1): "aa\nbxb\ncc"
        let newText = "aa\nbxb\ncc" as NSString
        index.update(editedRange: NSRange(location: 4, length: 0), changeInLength: 1, newText: newText)

        XCTAssertEqual(index.lineStarts, [0, 3, 7])
        XCTAssertEqual(index.textLength, 9)
    }

    func test_update_deleteNewline_mergesLines() {
        var index = LineIndex(text: "aa\nbb\ncc" as NSString)
        XCTAssertEqual(index.lineCount, 3)

        // Delete the first newline (position 2, length 1): "aabb\ncc"
        let newText = "aabb\ncc" as NSString
        index.update(editedRange: NSRange(location: 2, length: 1), changeInLength: -1, newText: newText)

        XCTAssertEqual(index.lineCount, 2)
        XCTAssertEqual(index.lineStarts, [0, 5])
        XCTAssertEqual(index.textLength, 7)
    }
}
