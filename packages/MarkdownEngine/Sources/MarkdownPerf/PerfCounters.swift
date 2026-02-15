import Foundation

// MARK: - PerfCounters

/// Atomic counters for the in-app performance HUD.
///
/// Updated from the pipeline stages and read by the HUD on the main thread.
/// All access is via atomics — no locks needed.
public final class PerfCounters: @unchecked Sendable {

    // MARK: - Counters

    /// Current document revision.
    public private(set) var revision: Int = 0

    /// Size of the last dirty range (UTF-16 units).
    public private(set) var dirtyRangeSize: Int = 0

    /// Size of the last safe reparse region (UTF-16 units).
    public private(set) var reparseRegionSize: Int = 0

    /// Last parse duration in microseconds.
    public private(set) var parseTimeMicros: Int = 0

    /// Last layout duration in microseconds.
    public private(set) var layoutTimeMicros: Int = 0

    /// Last preview apply duration in microseconds.
    public private(set) var applyTimeMicros: Int = 0

    /// Number of blocks changed in the last update.
    public private(set) var blocksChanged: Int = 0

    /// Total number of blocks in the document.
    public private(set) var totalBlocks: Int = 0

    /// Layout cache hit count (since last reset).
    public private(set) var cacheHits: Int = 0

    /// Layout cache miss count (since last reset).
    public private(set) var cacheMisses: Int = 0

    public init() {}

    // MARK: - Update Methods

    public func recordRevision(_ rev: Int) {
        revision = rev
    }

    public func recordDirtyRange(size: Int) {
        dirtyRangeSize = size
    }

    public func recordReparseRegion(size: Int) {
        reparseRegionSize = size
    }

    public func recordParseTime(microseconds: Int) {
        parseTimeMicros = microseconds
    }

    public func recordLayoutTime(microseconds: Int) {
        layoutTimeMicros = microseconds
    }

    public func recordApplyTime(microseconds: Int) {
        applyTimeMicros = microseconds
    }

    public func recordBlocksChanged(_ count: Int) {
        blocksChanged = count
    }

    public func recordTotalBlocks(_ count: Int) {
        totalBlocks = count
    }

    public func recordCacheHit() {
        cacheHits += 1
    }

    public func recordCacheMiss() {
        cacheMisses += 1
    }

    // MARK: - Read

    /// Cache hit rate as a percentage string.
    public var cacheHitRateString: String {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return "—" }
        let rate = Double(cacheHits) / Double(total) * 100
        return String(format: "%.1f%%", rate)
    }

    /// Summary string for the HUD.
    public var summary: String {
        """
        rev: \(revision) | dirty: \(dirtyRangeSize) | reparse: \(reparseRegionSize)
        parse: \(parseTimeMicros)µs | layout: \(layoutTimeMicros)µs | apply: \(applyTimeMicros)µs
        blocks: \(blocksChanged)/\(totalBlocks) changed | cache: \(cacheHitRateString)
        """
    }

    /// Reset all counters.
    public func reset() {
        revision = 0
        dirtyRangeSize = 0
        reparseRegionSize = 0
        parseTimeMicros = 0
        layoutTimeMicros = 0
        applyTimeMicros = 0
        blocksChanged = 0
        totalBlocks = 0
        cacheHits = 0
        cacheMisses = 0
    }
}

// MARK: - Timing Utility

/// Measure execution time in microseconds.
public func measureMicroseconds(_ block: () -> Void) -> Int {
    #if canImport(Darwin)
    let start = DispatchTime.now()
    block()
    let end = DispatchTime.now()
    let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
    return Int(nanos / 1000)
    #else
    let start = DispatchTime.now()
    block()
    let end = DispatchTime.now()
    let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
    return Int(nanos / 1000)
    #endif
}

/// Async version of measureMicroseconds.
public func measureMicrosecondsAsync(_ block: () async -> Void) async -> Int {
    let start = DispatchTime.now()
    await block()
    let end = DispatchTime.now()
    let nanos = end.uptimeNanoseconds - start.uptimeNanoseconds
    return Int(nanos / 1000)
}
