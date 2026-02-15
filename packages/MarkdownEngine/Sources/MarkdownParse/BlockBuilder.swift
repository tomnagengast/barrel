import Foundation
import MarkdownCore

// MARK: - BlockBuilder

/// Converts raw parse output into a well-formed `[BlockModel]` array with
/// accurate source ranges computed against the original document text.
///
/// The parser may produce approximate ranges (line/column based). `BlockBuilder`
/// post-processes these into precise UTF-16 `NSRange` values by scanning the
/// source text.
public struct BlockBuilder: Sendable {

    public init() {}

    /// Post-process blocks from a parser to have accurate UTF-16 ranges.
    ///
    /// - Parameters:
    ///   - blocks: Raw blocks from the parser.
    ///   - snapshot: The document snapshot (for text + line index).
    ///   - regionRange: The region that was parsed.
    /// - Returns: Blocks with corrected ranges and content hashes.
    public func build(
        blocks: [BlockModel],
        snapshot: DocumentSnapshot,
        regionRange: NSRange
    ) -> [BlockModel] {
        var result: [BlockModel] = []
        result.reserveCapacity(blocks.count)

        for block in blocks {
            var corrected = block

            // Clamp range to the valid region
            let clampedStart = max(block.range.location, regionRange.location)
            let clampedEnd = min(NSMaxRange(block.range), NSMaxRange(regionRange))
            if clampedStart >= clampedEnd {
                // Block is outside the region — skip it
                continue
            }
            corrected.range = NSRange(location: clampedStart, length: clampedEnd - clampedStart)

            // Recompute content hash from actual source text
            if corrected.range.length > 0 && NSMaxRange(corrected.range) <= snapshot.length {
                let sourceSlice = snapshot.substring(with: corrected.range)
                corrected.contentHash = fnv1aHash(sourceSlice)
            }

            result.append(corrected)
        }

        return result
    }

    /// Compute a content hash for a string.
    private func fnv1aHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

// MARK: - BlockDiff

/// The result of diffing old blocks against new blocks in a reparse region.
public struct BlockDiff: Sendable {
    /// Block IDs that no longer exist in the reparse region.
    public let removedIDs: [BlockID]
    /// New blocks inserted into the reparse region.
    public let insertedBlocks: [BlockModel]
    /// Existing blocks whose content changed (same position, different hash).
    public let updatedBlocks: [BlockModel]
    /// The change in length to shift ranges of blocks after the reparse region.
    public let rangeShiftDelta: Int

    public init(
        removedIDs: [BlockID],
        insertedBlocks: [BlockModel],
        updatedBlocks: [BlockModel],
        rangeShiftDelta: Int
    ) {
        self.removedIDs = removedIDs
        self.insertedBlocks = insertedBlocks
        self.updatedBlocks = updatedBlocks
        self.rangeShiftDelta = rangeShiftDelta
    }

    /// Whether this diff is empty (no changes).
    public var isEmpty: Bool {
        removedIDs.isEmpty && insertedBlocks.isEmpty && updatedBlocks.isEmpty
    }
}

// MARK: - Block Differ

/// Diffs old blocks against new blocks within a reparse region.
public struct BlockDiffer: Sendable {

    public init() {}

    /// Compute the diff between old and new blocks in a reparse region.
    ///
    /// - Parameters:
    ///   - oldBlocks: Blocks from the previous parse that overlap the reparse region.
    ///   - newBlocks: Blocks from the fresh parse of the reparse region.
    ///   - changeInLength: The total change in document length from the edit.
    /// - Returns: A `BlockDiff` describing what changed.
    public func diff(
        oldBlocks: [BlockModel],
        newBlocks: [BlockModel],
        changeInLength: Int
    ) -> BlockDiff {
        // Build lookup of old blocks by (kind, contentHash) for matching
        var oldBySignature: [BlockSignature: [BlockModel]] = [:]
        for block in oldBlocks {
            let sig = BlockSignature(kind: block.kind, contentHash: block.contentHash)
            oldBySignature[sig, default: []].append(block)
        }

        var removed: [BlockID] = []
        var inserted: [BlockModel] = []
        var updated: [BlockModel] = []
        var matchedOldIDs: Set<BlockID> = []

        for newBlock in newBlocks {
            let sig = BlockSignature(kind: newBlock.kind, contentHash: newBlock.contentHash)
            if var candidates = oldBySignature[sig], !candidates.isEmpty {
                // Match: preserve old block's ID
                let oldBlock = candidates.removeFirst()
                oldBySignature[sig] = candidates
                matchedOldIDs.insert(oldBlock.id)

                // If range changed, it's an update (same content, moved position)
                if oldBlock.range != newBlock.range {
                    var updatedBlock = newBlock
                    // Keep the stable ID from the old block
                    updatedBlock = BlockModel(
                        id: oldBlock.id,
                        kind: newBlock.kind,
                        range: newBlock.range,
                        inlines: newBlock.inlines,
                        metadata: newBlock.metadata,
                        contentHash: newBlock.contentHash
                    )
                    updated.append(updatedBlock)
                }
            } else {
                // No match: this is a new block
                inserted.append(newBlock)
            }
        }

        // Old blocks that weren't matched are removed
        for block in oldBlocks where !matchedOldIDs.contains(block.id) {
            removed.append(block.id)
        }

        return BlockDiff(
            removedIDs: removed,
            insertedBlocks: inserted,
            updatedBlocks: updated,
            rangeShiftDelta: changeInLength
        )
    }
}

/// Internal key for matching blocks by structure and content.
private struct BlockSignature: Hashable {
    let kind: BlockKind
    let contentHash: UInt64
}
