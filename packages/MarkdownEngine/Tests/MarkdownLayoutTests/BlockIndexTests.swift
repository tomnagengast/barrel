import XCTest
@testable import MarkdownCore
@testable import MarkdownLayout

final class BlockIndexTests: XCTestCase {

    func test_blockIndex_replaceAll_sortsByLocation() {
        var index = BlockIndex()
        let gen = BlockIDGenerator()

        let b1 = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 20, length: 10))
        let b2 = BlockModel(id: gen.next(), kind: .heading(level: 1), range: NSRange(location: 0, length: 10))
        let b3 = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 10, length: 10))

        index.replaceAll(blocks: [b1, b2, b3])

        XCTAssertEqual(index.blocks.count, 3)
        XCTAssertEqual(index.blocks[0].range.location, 0)
        XCTAssertEqual(index.blocks[1].range.location, 10)
        XCTAssertEqual(index.blocks[2].range.location, 20)
    }

    func test_blockIndex_containingOffset_findsBlock() {
        var index = BlockIndex()
        let gen = BlockIDGenerator()

        let b1 = BlockModel(id: gen.next(), kind: .heading(level: 1), range: NSRange(location: 0, length: 10))
        let b2 = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 10, length: 20))
        let b3 = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 30, length: 10))

        index.replaceAll(blocks: [b1, b2, b3])

        XCTAssertEqual(index.blockIndex(containingOffset: 0), 0)
        XCTAssertEqual(index.blockIndex(containingOffset: 5), 0)
        XCTAssertEqual(index.blockIndex(containingOffset: 15), 1)
        XCTAssertEqual(index.blockIndex(containingOffset: 35), 2)
    }

    func test_blockIndex_containingOffset_returnsNilForGap() {
        var index = BlockIndex()
        let gen = BlockIDGenerator()

        // Gap between 10 and 20
        let b1 = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 0, length: 10))
        let b2 = BlockModel(id: gen.next(), kind: .paragraph, range: NSRange(location: 20, length: 10))

        index.replaceAll(blocks: [b1, b2])

        XCTAssertNil(index.blockIndex(containingOffset: 15))
    }

    func test_blockIndex_totalHeight_sumsLayouts() {
        var index = BlockIndex()
        let gen = BlockIDGenerator()

        let id1 = gen.next()
        let id2 = gen.next()

        let b1 = BlockModel(id: id1, kind: .paragraph, range: NSRange(location: 0, length: 10))
        let b2 = BlockModel(id: id2, kind: .paragraph, range: NSRange(location: 10, length: 10))

        index.replaceAll(blocks: [b1, b2])

        let layout1 = LayoutBlock(id: id1, measuredHeight: 30, sourceRange: b1.range, kind: .paragraph, drawPayload: .none)
        let layout2 = LayoutBlock(id: id2, measuredHeight: 50, sourceRange: b2.range, kind: .paragraph, drawPayload: .none)

        index.updateLayout(layout1)
        index.updateLayout(layout2)

        XCTAssertEqual(index.totalHeight, 80)
    }

    func test_blockIndex_atYOffset_findsCorrectBlock() {
        var index = BlockIndex()
        let gen = BlockIDGenerator()

        let id1 = gen.next()
        let id2 = gen.next()
        let id3 = gen.next()

        let b1 = BlockModel(id: id1, kind: .paragraph, range: NSRange(location: 0, length: 10))
        let b2 = BlockModel(id: id2, kind: .paragraph, range: NSRange(location: 10, length: 10))
        let b3 = BlockModel(id: id3, kind: .paragraph, range: NSRange(location: 20, length: 10))

        index.replaceAll(blocks: [b1, b2, b3])

        let layout1 = LayoutBlock(id: id1, measuredHeight: 100, sourceRange: b1.range, kind: .paragraph, drawPayload: .none)
        let layout2 = LayoutBlock(id: id2, measuredHeight: 200, sourceRange: b2.range, kind: .paragraph, drawPayload: .none)
        let layout3 = LayoutBlock(id: id3, measuredHeight: 100, sourceRange: b3.range, kind: .paragraph, drawPayload: .none)

        index.updateLayout(layout1)
        index.updateLayout(layout2)
        index.updateLayout(layout3)

        XCTAssertEqual(index.blockIndex(atYOffset: 0), 0)
        XCTAssertEqual(index.blockIndex(atYOffset: 50), 0)
        XCTAssertEqual(index.blockIndex(atYOffset: 100), 1)
        XCTAssertEqual(index.blockIndex(atYOffset: 250), 1)
        XCTAssertEqual(index.blockIndex(atYOffset: 300), 2)
    }
}
