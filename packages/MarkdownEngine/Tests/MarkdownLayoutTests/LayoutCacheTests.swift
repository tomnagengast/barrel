import XCTest
@testable import MarkdownCore
@testable import MarkdownLayout

final class LayoutCacheTests: XCTestCase {

    func test_cache_setAndGet_returnsValue() {
        var cache = LayoutCache(maxEntries: 10)
        let blockID = BlockID(rawValue: 1)
        let key = LayoutKey(blockID: blockID, width: 600, themeVariant: 0, contentHash: 42)
        let layout = LayoutBlock(
            id: blockID,
            measuredHeight: 20,
            sourceRange: NSRange(location: 0, length: 10),
            kind: .paragraph,
            drawPayload: .none
        )

        cache.set(key: key, value: layout)
        let result = cache.get(key: key)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, blockID)
        XCTAssertEqual(result?.measuredHeight, 20)
    }

    func test_cache_miss_returnsNil() {
        var cache = LayoutCache(maxEntries: 10)
        let key = LayoutKey(blockID: BlockID(rawValue: 999), width: 600, themeVariant: 0, contentHash: 0)

        let result = cache.get(key: key)
        XCTAssertNil(result)
    }

    func test_cache_eviction_removesOldestEntry() {
        var cache = LayoutCache(maxEntries: 2)

        let key1 = LayoutKey(blockID: BlockID(rawValue: 1), width: 600, themeVariant: 0, contentHash: 1)
        let key2 = LayoutKey(blockID: BlockID(rawValue: 2), width: 600, themeVariant: 0, contentHash: 2)
        let key3 = LayoutKey(blockID: BlockID(rawValue: 3), width: 600, themeVariant: 0, contentHash: 3)

        let layout1 = LayoutBlock(id: BlockID(rawValue: 1), measuredHeight: 10, sourceRange: NSRange(location: 0, length: 5), kind: .paragraph, drawPayload: .none)
        let layout2 = LayoutBlock(id: BlockID(rawValue: 2), measuredHeight: 20, sourceRange: NSRange(location: 5, length: 5), kind: .paragraph, drawPayload: .none)
        let layout3 = LayoutBlock(id: BlockID(rawValue: 3), measuredHeight: 30, sourceRange: NSRange(location: 10, length: 5), kind: .paragraph, drawPayload: .none)

        cache.set(key: key1, value: layout1)
        cache.set(key: key2, value: layout2)
        cache.set(key: key3, value: layout3) // should evict key1

        XCTAssertNil(cache.get(key: key1))
        XCTAssertNotNil(cache.get(key: key2))
        XCTAssertNotNil(cache.get(key: key3))
    }

    func test_cache_clear_removesEverything() {
        var cache = LayoutCache(maxEntries: 10)
        let key = LayoutKey(blockID: BlockID(rawValue: 1), width: 600, themeVariant: 0, contentHash: 1)
        let layout = LayoutBlock(id: BlockID(rawValue: 1), measuredHeight: 10, sourceRange: NSRange(location: 0, length: 5), kind: .paragraph, drawPayload: .none)

        cache.set(key: key, value: layout)
        cache.clear()

        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.get(key: key))
    }

    func test_cache_removeAllForBlockID() {
        var cache = LayoutCache(maxEntries: 10)
        let blockID = BlockID(rawValue: 1)

        // Same block, different widths
        let key1 = LayoutKey(blockID: blockID, width: 600, themeVariant: 0, contentHash: 1)
        let key2 = LayoutKey(blockID: blockID, width: 800, themeVariant: 0, contentHash: 1)
        let layout = LayoutBlock(id: blockID, measuredHeight: 10, sourceRange: NSRange(location: 0, length: 5), kind: .paragraph, drawPayload: .none)

        cache.set(key: key1, value: layout)
        cache.set(key: key2, value: layout)

        cache.removeAll(forBlockID: blockID)

        XCTAssertNil(cache.get(key: key1))
        XCTAssertNil(cache.get(key: key2))
    }

    func test_cache_widthBucketPreventsChurn() {
        // Widths 600 and 604 should have the same bucket (600/8 = 75, 604/8 = 75)
        let key1 = LayoutKey(blockID: BlockID(rawValue: 1), width: 600, themeVariant: 0, contentHash: 1)
        let key2 = LayoutKey(blockID: BlockID(rawValue: 1), width: 604, themeVariant: 0, contentHash: 1)

        XCTAssertEqual(key1.widthBucket, key2.widthBucket)
        XCTAssertEqual(key1, key2) // same cache key
    }

    func test_cache_differentThemeVariant_differentKey() {
        let key1 = LayoutKey(blockID: BlockID(rawValue: 1), width: 600, themeVariant: 0, contentHash: 1)
        let key2 = LayoutKey(blockID: BlockID(rawValue: 1), width: 600, themeVariant: 1, contentHash: 1)

        XCTAssertNotEqual(key1, key2)
    }
}
