import Foundation

// MARK: - BlockID

/// Stable identity for a block across edits.
///
/// When an edit shifts block offsets but does not change a block's content,
/// the block keeps its `BlockID`. This lets caches survive offset shifts.
public struct BlockID: Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

// MARK: - BlockID Generator

/// Thread-safe monotonic generator for block IDs.
public final class BlockIDGenerator: @unchecked Sendable {
    private var _next: UInt64

    public init(startingAt value: UInt64 = 1) {
        _next = value
    }

    /// Returns the next unique `BlockID`. Not thread-safe — call from a single context.
    public func next() -> BlockID {
        let id = BlockID(rawValue: _next)
        _next += 1
        return id
    }
}

// MARK: - BlockKind

/// The structural kind of a Markdown block element.
public enum BlockKind: Hashable, Sendable {
    case heading(level: Int)    // 1–6
    case paragraph
    case codeBlock              // fenced or indented
    case blockquote
    case orderedList
    case unorderedList
    case listItem
    case thematicBreak
    /// Container for the full document root (used internally by parsers).
    case document
}

// MARK: - InlineKind

/// The kind of an inline Markdown span.
public enum InlineKind: Hashable, Sendable {
    case text
    case emphasis
    case strong
    case code
    case link(destination: String)
    case softBreak
    case lineBreak
}

// MARK: - InlineSpan

/// A span of inline content within a block.
public struct InlineSpan: Sendable {
    public let kind: InlineKind
    /// Range within the block's source text (relative to block start), UTF-16 offsets.
    public let range: NSRange
    /// The text content of this span.
    public let text: String

    public init(kind: InlineKind, range: NSRange, text: String) {
        self.kind = kind
        self.range = range
        self.text = text
    }
}

// MARK: - BlockMetadata

/// Extra metadata attached to a block depending on its kind.
public struct BlockMetadata: Hashable, Sendable {
    /// Heading level (1–6), meaningful only for `.heading`.
    public var headingLevel: Int
    /// Language tag for fenced code blocks.
    public var fenceLanguage: String?
    /// Nesting depth for list items / blockquotes.
    public var nestingDepth: Int

    public init(headingLevel: Int = 0, fenceLanguage: String? = nil, nestingDepth: Int = 0) {
        self.headingLevel = headingLevel
        self.fenceLanguage = fenceLanguage
        self.nestingDepth = nestingDepth
    }
}

// MARK: - BlockModel

/// A single Markdown block extracted from the document.
///
/// This is the fundamental unit passed through the pipeline:
/// parse → diff → layout → render.
public struct BlockModel: Identifiable, Sendable {
    public let id: BlockID
    public let kind: BlockKind
    /// Source range in UTF-16 offsets (matches NSString / NSRange).
    public var range: NSRange
    /// Inline spans for blocks that contain inline content (headings, paragraphs, list items).
    public var inlines: [InlineSpan]
    /// Block-specific metadata.
    public var metadata: BlockMetadata
    /// Hash of the source slice for this block, used for cache invalidation.
    public var contentHash: UInt64

    public init(
        id: BlockID,
        kind: BlockKind,
        range: NSRange,
        inlines: [InlineSpan] = [],
        metadata: BlockMetadata = BlockMetadata(),
        contentHash: UInt64 = 0
    ) {
        self.id = id
        self.kind = kind
        self.range = range
        self.inlines = inlines
        self.metadata = metadata
        self.contentHash = contentHash
    }
}
