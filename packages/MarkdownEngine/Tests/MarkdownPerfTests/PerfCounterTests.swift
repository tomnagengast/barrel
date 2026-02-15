import XCTest
@testable import MarkdownPerf

final class PerfCounterTests: XCTestCase {

    func test_counters_initiallyZero() {
        let counters = PerfCounters()
        XCTAssertEqual(counters.revision, 0)
        XCTAssertEqual(counters.dirtyRangeSize, 0)
        XCTAssertEqual(counters.parseTimeMicros, 0)
        XCTAssertEqual(counters.totalBlocks, 0)
    }

    func test_counters_recordAndRead() {
        let counters = PerfCounters()
        counters.recordRevision(42)
        counters.recordDirtyRange(size: 100)
        counters.recordParseTime(microseconds: 500)
        counters.recordLayoutTime(microseconds: 200)
        counters.recordTotalBlocks(10)
        counters.recordBlocksChanged(3)

        XCTAssertEqual(counters.revision, 42)
        XCTAssertEqual(counters.dirtyRangeSize, 100)
        XCTAssertEqual(counters.parseTimeMicros, 500)
        XCTAssertEqual(counters.layoutTimeMicros, 200)
        XCTAssertEqual(counters.totalBlocks, 10)
        XCTAssertEqual(counters.blocksChanged, 3)
    }

    func test_counters_reset_clearsAll() {
        let counters = PerfCounters()
        counters.recordRevision(10)
        counters.recordParseTime(microseconds: 999)
        counters.reset()

        XCTAssertEqual(counters.revision, 0)
        XCTAssertEqual(counters.parseTimeMicros, 0)
    }

    func test_counters_cacheHitRate() {
        let counters = PerfCounters()
        counters.recordCacheHit()
        counters.recordCacheHit()
        counters.recordCacheHit()
        counters.recordCacheMiss()

        // 3 hits / 4 total = 75%
        XCTAssertTrue(counters.cacheHitRateString.contains("75"))
    }

    func test_measureMicroseconds_returnsPositive() {
        let elapsed = measureMicroseconds {
            // Some trivial work
            var sum = 0
            for i in 0..<1000 {
                sum += i
            }
            _ = sum
        }
        XCTAssertGreaterThanOrEqual(elapsed, 0)
    }
}
