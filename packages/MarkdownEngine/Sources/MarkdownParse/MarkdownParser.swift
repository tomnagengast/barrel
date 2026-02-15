import Foundation
import MarkdownCore

// MARK: - MarkdownParser

/// Abstraction over Markdown parsing implementations.
///
/// The parser takes a text region and produces an array of `BlockModel`s.
/// Implementations are pluggable — the engine does not depend on which
/// concrete parser is in use (cmark-gfm, tree-sitter, etc.).
public protocol MarkdownParser: Sendable {
    /// Parse the given text region and return block models.
    ///
    /// - Parameters:
    ///   - text: The full document text.
    ///   - range: The region to parse (UTF-16 range).
    ///            The parser may read slightly outside this range for context
    ///            but will only produce blocks whose ranges fall within it.
    ///   - idGenerator: Generator for assigning stable block IDs.
    /// - Returns: An array of `BlockModel` covering the parsed region, ordered by range.
    func parse(
        text: NSString,
        range: NSRange,
        idGenerator: BlockIDGenerator
    ) -> [BlockModel]

    /// Parse the full document. Convenience for initial load.
    func parseFullDocument(
        text: NSString,
        idGenerator: BlockIDGenerator
    ) -> [BlockModel]
}

extension MarkdownParser {
    public func parseFullDocument(
        text: NSString,
        idGenerator: BlockIDGenerator
    ) -> [BlockModel] {
        parse(
            text: text,
            range: NSRange(location: 0, length: text.length),
            idGenerator: idGenerator
        )
    }
}
