import XCTest
@testable import MarkdownCore
@testable import MarkdownParse

final class BlockBuilderTests: XCTestCase {

    func test_build_clampsRangeToRegion() {
        let builder = BlockBuilder()
        let gen = BlockIDGenerator()

        let text = "Hello\nWorld\nFoo" as NSString
        let snapshot = DocumentSnapshot(text: text, revision: 1, lineIndex: LineIndex(text: text))

        // Create a block with range extending beyond the region
        let block = BlockModel(
            id: gen.next(),
            kind: .paragraph,
            range: NSRange(location: 0, length: 15), // full document
            contentHash: 0
        )

        let region = NSRange(location: 6, length: 5) // "World" only
        let result = builder.build(blocks: [block], snapshot: snapshot, regionRange: region)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].range.location, 6)
        XCTAssertEqual(result[0].range.length, 5)
    }

    func test_build_skipsBlocksOutsideRegion() {
        let builder = BlockBuilder()
        let gen = BlockIDGenerator()

        let text = "AAA\nBBB\nCCC" as NSString
        let snapshot = DocumentSnapshot(text: text, revision: 1, lineIndex: LineIndex(text: text))

        let block = BlockModel(
            id: gen.next(),
            kind: .paragraph,
            range: NSRange(location: 0, length: 3), // "AAA"
            contentHash: 0
        )

        let region = NSRange(location: 8, length: 3) // "CCC" only
        let result = builder.build(blocks: [block], snapshot: snapshot, regionRange: region)

        XCTAssertEqual(result.count, 0)
    }

    func test_build_recomputesContentHash() {
        let builder = BlockBuilder()
        let gen = BlockIDGenerator()

        let text = "Hello World" as NSString
        let snapshot = DocumentSnapshot(text: text, revision: 1, lineIndex: LineIndex(text: text))

        let block = BlockModel(
            id: gen.next(),
            kind: .paragraph,
            range: NSRange(location: 0, length: 11),
            contentHash: 12345 // dummy hash
        )

        let result = builder.build(blocks: [block], snapshot: snapshot, regionRange: NSRange(location: 0, length: 11))
        XCTAssertEqual(result.count, 1)
        XCTAssertNotEqual(result[0].contentHash, 12345) // should be recomputed
    }
}

final class BlockDifferTests: XCTestCase {

    func test_diff_noChanges_emptyDiff() {
        let differ = BlockDiffer()
        let gen = BlockIDGenerator()

        let block = BlockModel(
            id: gen.next(),
            kind: .paragraph,
            range: NSRange(location: 0, length: 10),
            contentHash: 42
        )

        let diff = differ.diff(oldBlocks: [block], newBlocks: [block], changeInLength: 0)
        XCTAssertTrue(diff.isEmpty)
    }

    func test_diff_removedBlock_appearsInRemovedIDs() {
        let differ = BlockDiffer()
        let gen = BlockIDGenerator()

        let old = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 0, length: 10), contentHash: 1)

        let diff = differ.diff(oldBlocks: [old], newBlocks: [], changeInLength: -10)
        XCTAssertEqual(diff.removedIDs, [old.id])
        XCTAssertTrue(diff.insertedBlocks.isEmpty)
    }

    func test_diff_insertedBlock_appearsInInserted() {
        let differ = BlockDiffer()
        let gen = BlockIDGenerator()

        let new = BlockModel(id: gen.next(), kind: .heading(level: 1), range: NSRange(location: 0, length: 10), contentHash: 99)

        let diff = differ.diff(oldBlocks: [], newBlocks: [new], changeInLength: 10)
        XCTAssertEqual(diff.insertedBlocks.count, 1)
        XCTAssertEqual(diff.insertedBlocks[0].id, new.id)
        XCTAssertTrue(diff.removedIDs.isEmpty)
    }

    func test_diff_contentChanged_oldRemovedNewInserted() {
        let differ = BlockDiffer()
        let gen = BlockIDGenerator()

        let old = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 0, length: 10), contentHash: 1)
        let new = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 0, length: 12), contentHash: 2)

        let diff = differ.diff(oldBlocks: [old], newBlocks: [new], changeInLength: 2)
        // Different content hash means no match — old is removed, new is inserted
        XCTAssertEqual(diff.removedIDs.count, 1)
        XCTAssertEqual(diff.insertedBlocks.count, 1)
    }
}
