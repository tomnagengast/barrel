import Foundation
import MarkdownCore

// MARK: - LayoutCache

/// LRU cache for `LayoutBlock` results keyed by `LayoutKey`.
///
/// Thread safety: this type is NOT thread-safe. Access it from a single
/// context (the layout coordinator actor).
public struct LayoutCache: Sendable {
    /// Maximum number of entries before eviction.
    public let maxEntries: Int

    /// Cache storage ordered by recency (most recent at end).
    private var entries: [(key: LayoutKey, value: LayoutBlock)]

    /// Fast lookup index.
    private var index: [LayoutKey: Int]

    public init(maxEntries: Int = 2048) {
        self.maxEntries = maxEntries
        self.entries = []
        self.index = [:]
    }

    // MARK: - Access

    /// Look up a cached layout. Returns `nil` on miss.
    /// Moves the entry to the end (most recent) on hit.
    public mutating func get(key: LayoutKey) -> LayoutBlock? {
        guard let idx = index[key] else { return nil }
        let entry = entries[idx]

        // Move to end for LRU
        entries.remove(at: idx)
        entries.append(entry)
        rebuildIndex()

        return entry.value
    }

    /// Store a layout result. Evicts the oldest entry if at capacity.
    public mutating func set(key: LayoutKey, value: LayoutBlock) {
        if let existingIdx = index[key] {
            entries.remove(at: existingIdx)
        }

        entries.append((key: key, value: value))

        if entries.count > maxEntries {
            let removed = entries.removeFirst()
            index.removeValue(forKey: removed.key)
        }

        rebuildIndex()
    }

    /// Remove a specific entry.
    public mutating func remove(key: LayoutKey) {
        if let idx = index[key] {
            entries.remove(at: idx)
            rebuildIndex()
        }
    }

    /// Remove all entries for a given block ID (any width/theme variant).
    public mutating func removeAll(forBlockID blockID: BlockID) {
        entries.removeAll { $0.key.blockID == blockID }
        rebuildIndex()
    }

    /// Clear the entire cache. Called on theme change.
    public mutating func clear() {
        entries.removeAll()
        index.removeAll()
    }

    /// Number of cached entries.
    public var count: Int { entries.count }

    /// Hit rate tracking (for perf HUD).
    public private(set) var hits: Int = 0
    public private(set) var misses: Int = 0

    public var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0
    }

    public mutating func resetStats() {
        hits = 0
        misses = 0
    }

    // MARK: - Internal

    private mutating func rebuildIndex() {
        index.removeAll(keepingCapacity: true)
        for (i, entry) in entries.enumerated() {
            index[entry.key] = i
        }
    }
}
