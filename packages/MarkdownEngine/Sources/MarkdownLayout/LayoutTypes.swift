import Foundation
import MarkdownCore

// MARK: - LayoutBlock

/// A block that has been measured and is ready for drawing.
///
/// Produced by `LayoutEngine`, consumed by a preview renderer.
public struct LayoutBlock: Sendable {
    /// The block's stable identity (matches `BlockModel.id`).
    public let id: BlockID
    /// Measured height for this block at the given width.
    public var measuredHeight: CGFloat
    /// The source range this block covers (for click-to-jump).
    public var sourceRange: NSRange
    /// The kind of block (for style decisions at draw time).
    public var kind: BlockKind
    /// Backend-specific drawing data.
    public var drawPayload: DrawPayload
    /// Rectangles for clickable links, mapped to source ranges.
    public var linkRects: [(sourceRange: NSRange, rect: CGRect)]

    public init(
        id: BlockID,
        measuredHeight: CGFloat,
        sourceRange: NSRange,
        kind: BlockKind,
        drawPayload: DrawPayload,
        linkRects: [(sourceRange: NSRange, rect: CGRect)] = []
    ) {
        self.id = id
        self.measuredHeight = measuredHeight
        self.sourceRange = sourceRange
        self.kind = kind
        self.drawPayload = drawPayload
        self.linkRects = linkRects
    }
}

// MARK: - DrawPayload

/// Backend-specific data needed to draw a block.
///
/// Stage 1 (TextKit): an `NSAttributedString`.
/// Stage 2 (CoreText): a `CTFrame` plus line metrics.
public enum DrawPayload: Sendable {
    /// Attributed string for TextKit-based preview.
    case attributedString(NSAttributedString)
    /// Placeholder for CoreText backend (not yet implemented).
    case coreTextPlaceholder
    /// Empty / not yet laid out.
    case none
}

// MARK: - LayoutKey

/// Cache key for a laid-out block.
///
/// Two blocks with the same `LayoutKey` produce identical layout results.
public struct LayoutKey: Hashable, Sendable {
    public let blockID: BlockID
    /// Width bucketed to nearest 8pt to avoid relayout on tiny resizes.
    public let widthBucket: Int
    /// Theme variant (e.g. 0 = light, 1 = dark).
    public let themeVariant: Int
    /// Hash of the block's source content.
    public let contentHash: UInt64

    public init(blockID: BlockID, width: CGFloat, themeVariant: Int, contentHash: UInt64) {
        self.blockID = blockID
        self.widthBucket = Int(floor(width / 8.0))
        self.themeVariant = themeVariant
        self.contentHash = contentHash
    }
}

// MARK: - ThemeStyle

/// Minimal theme definition for layout and rendering.
///
/// v1: two themes only (light and dark). No custom theme support.
public struct ThemeStyle: Sendable {
    public let variant: Int  // 0 = light, 1 = dark

    public let bodyFontSize: CGFloat
    public let headingScales: [CGFloat]  // index 0 = h1 scale, 1 = h2, etc.
    public let codeFontSize: CGFloat
    public let lineSpacing: CGFloat
    public let paragraphSpacing: CGFloat
    public let blockquoteIndent: CGFloat
    public let listIndent: CGFloat

    public init(
        variant: Int = 0,
        bodyFontSize: CGFloat = 14,
        headingScales: [CGFloat] = [2.0, 1.5, 1.25, 1.1, 1.0, 0.9],
        codeFontSize: CGFloat = 13,
        lineSpacing: CGFloat = 4,
        paragraphSpacing: CGFloat = 12,
        blockquoteIndent: CGFloat = 20,
        listIndent: CGFloat = 24
    ) {
        self.variant = variant
        self.bodyFontSize = bodyFontSize
        self.headingScales = headingScales
        self.codeFontSize = codeFontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.blockquoteIndent = blockquoteIndent
        self.listIndent = listIndent
    }

    public static let light = ThemeStyle(variant: 0)
    public static let dark = ThemeStyle(variant: 1)
}

// MARK: - BlockIndex

/// Ordered collection of blocks with fast lookup by source location.
///
/// Maintains blocks sorted by `range.location` and supports:
/// - Binary search by source offset
/// - Prefix-sum heights for fast scroll offset computation
public struct BlockIndex: Sendable {
    /// Blocks ordered by source range location.
    public private(set) var blocks: [BlockModel]

    /// Layout results keyed by block ID. Not all blocks may be laid out.
    public private(set) var layouts: [BlockID: LayoutBlock]

    /// Prefix sums of block heights, for scroll computation.
    /// `heightPrefixSums[i]` = sum of heights of blocks 0..<i.
    public private(set) var heightPrefixSums: [CGFloat]

    public init() {
        self.blocks = []
        self.layouts = [:]
        self.heightPrefixSums = [0]
    }

    /// Replace all blocks. Used on initial load.
    public mutating func replaceAll(blocks: [BlockModel]) {
        self.blocks = blocks.sorted { $0.range.location < $1.range.location }
        self.layouts = [:]
        self.heightPrefixSums = [0]
    }

    /// Find the index of the block containing the given source offset.
    /// Returns `nil` if no block contains the offset.
    public func blockIndex(containingOffset offset: Int) -> Int? {
        var lo = 0
        var hi = blocks.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            let block = blocks[mid]
            if NSMaxRange(block.range) <= offset {
                lo = mid + 1
            } else if block.range.location > offset {
                hi = mid
            } else {
                return mid
            }
        }
        return nil
    }

    /// Update layout for a block and recompute affected prefix sums.
    public mutating func updateLayout(_ layout: LayoutBlock) {
        layouts[layout.id] = layout
        recomputeHeightPrefixSums()
    }

    /// Recompute the full prefix sums array. Called after layout changes.
    public mutating func recomputeHeightPrefixSums() {
        var sums: [CGFloat] = [0]
        sums.reserveCapacity(blocks.count + 1)
        for block in blocks {
            let height = layouts[block.id]?.measuredHeight ?? 0
            sums.append(sums.last! + height)
        }
        heightPrefixSums = sums
    }

    /// Total height of all laid-out blocks.
    public var totalHeight: CGFloat {
        heightPrefixSums.last ?? 0
    }

    /// Find which block is visible at the given y-offset (for scroll).
    public func blockIndex(atYOffset y: CGFloat) -> Int? {
        guard !blocks.isEmpty else { return nil }
        var lo = 0
        var hi = blocks.count
        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if heightPrefixSums[mid + 1] <= y {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo < blocks.count ? lo : nil
    }
}
