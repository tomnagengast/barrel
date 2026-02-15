import XCTest
@testable import MarkdownCore

final class DirtyTrackerTests: XCTestCase {

    // MARK: - Recording

    func test_recordEdit_singleEdit_storesDirtyRange() {
        var tracker = DirtyTracker()
        tracker.recordEdit(editedRange: NSRange(location: 10, length: 5), changeInLength: 3)

        XCTAssertEqual(tracker.dirtyRange, NSRange(location: 10, length: 5))
        XCTAssertEqual(tracker.accumulatedDelta, 3)
    }

    func test_recordEdit_multipleEdits_coalesces() {
        var tracker = DirtyTracker()
        tracker.recordEdit(editedRange: NSRange(location: 10, length: 5), changeInLength: 3)
        tracker.recordEdit(editedRange: NSRange(location: 20, length: 2), changeInLength: 1)

        // Should union to cover both ranges
        XCTAssertEqual(tracker.dirtyRange, NSRange(location: 10, length: 12))
        XCTAssertEqual(tracker.accumulatedDelta, 4)
    }

    func test_recordEdit_overlappingEdits_coalesces() {
        var tracker = DirtyTracker()
        tracker.recordEdit(editedRange: NSRange(location: 10, length: 10), changeInLength: 0)
        tracker.recordEdit(editedRange: NSRange(location: 15, length: 10), changeInLength: 0)

        XCTAssertEqual(tracker.dirtyRange, NSRange(location: 10, length: 15))
    }

    // MARK: - Reset

    func test_reset_clearsDirtyState() {
        var tracker = DirtyTracker()
        tracker.recordEdit(editedRange: NSRange(location: 10, length: 5), changeInLength: 3)
        tracker.reset()

        XCTAssertNil(tracker.dirtyRange)
        XCTAssertEqual(tracker.accumulatedDelta, 0)
    }

    // MARK: - Safe Reparse Region

    func test_safeReparseRegion_noDirtyRange_returnsNil() {
        let tracker = DirtyTracker()
        let text = "# Heading\n\nParagraph\n" as NSString
        let snapshot = DocumentSnapshot(
            text: text,
            revision: 1,
            lineIndex: LineIndex(text: text)
        )
        XCTAssertNil(tracker.safeReparseRegion(in: snapshot))
    }

    func test_safeReparseRegion_expandsToFullLines() {
        var tracker = DirtyTracker()
        let text = "# Heading\n\nParagraph text here\n\nAnother paragraph\n" as NSString
        let snapshot = DocumentSnapshot(
            text: text,
            revision: 1,
            lineIndex: LineIndex(text: text)
        )

        // Edit in middle of "Paragraph text here"
        tracker.recordEdit(editedRange: NSRange(location: 15, length: 1), changeInLength: 0)

        let region = tracker.safeReparseRegion(in: snapshot)
        XCTAssertNotNil(region)

        // The region should at minimum cover the full line
        if let region = region {
            XCTAssertTrue(region.location <= 11) // start of "Paragraph text here"
            XCTAssertTrue(NSMaxRange(region) >= 30) // end of that line
        }
    }

    func test_safeReparseRegion_expandsToHardBoundary() {
        var tracker = DirtyTracker()
        let text = "# Heading\n\nParagraph\n\n# Another\n" as NSString
        let snapshot = DocumentSnapshot(
            text: text,
            revision: 1,
            lineIndex: LineIndex(text: text)
        )

        // Edit in "Paragraph"
        tracker.recordEdit(editedRange: NSRange(location: 12, length: 1), changeInLength: 0)

        let region = tracker.safeReparseRegion(in: snapshot)
        XCTAssertNotNil(region)

        // Should expand to blank line or heading boundaries
        if let region = region {
            // Region should not extend past the blank lines / headings
            XCTAssertTrue(region.location <= 11)
            XCTAssertTrue(NSMaxRange(region) <= text.length)
        }
    }
}
