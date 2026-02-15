import XCTest
@testable import MarkdownCore

final class BlockIDTests: XCTestCase {

    func test_blockIDGenerator_producesUniqueIDs() {
        let gen = BlockIDGenerator()
        let id1 = gen.next()
        let id2 = gen.next()
        let id3 = gen.next()

        XCTAssertNotEqual(id1, id2)
        XCTAssertNotEqual(id2, id3)
        XCTAssertNotEqual(id1, id3)
    }

    func test_blockIDGenerator_startsFromSpecifiedValue() {
        let gen = BlockIDGenerator(startingAt: 100)
        let id = gen.next()
        XCTAssertEqual(id.rawValue, 100)
    }

    func test_blockID_equality() {
        let a = BlockID(rawValue: 42)
        let b = BlockID(rawValue: 42)
        let c = BlockID(rawValue: 43)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func test_blockModel_identifiable() {
        let gen = BlockIDGenerator()
        let model = BlockModel(
            id: gen.next(),
            kind: .paragraph,
            range: NSRange(location: 0, length: 10)
        )
        XCTAssertEqual(model.id, model.id)
    }

    func test_blockKind_headingLevels() {
        let h1 = BlockKind.heading(level: 1)
        let h2 = BlockKind.heading(level: 2)
        let h1b = BlockKind.heading(level: 1)

        XCTAssertEqual(h1, h1b)
        XCTAssertNotEqual(h1, h2)
    }
}
