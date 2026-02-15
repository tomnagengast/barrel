import Foundation
import MarkdownCore
import Ccmark

// MARK: - CmarkParser

/// A `MarkdownParser` backed by cmark-gfm.
///
/// Uses the C cmark-gfm library for parsing. Produces `BlockModel` arrays
/// by walking the cmark AST and extracting block structure and inline spans.
public struct CmarkParser: MarkdownParser, Sendable {

    /// cmark-gfm extensions to enable. Default: none (pure CommonMark).
    /// Add "table", "strikethrough", "tasklist" etc. as needed.
    public let extensions: [String]

    public init(extensions: [String] = []) {
        self.extensions = extensions
    }

    public func parse(
        text: NSString,
        range: NSRange,
        idGenerator: BlockIDGenerator
    ) -> [BlockModel] {
        // Extract the substring for the region to parse.
        let regionText: String
        if range.location == 0 && range.length == text.length {
            regionText = text as String
        } else {
            regionText = text.substring(with: range)
        }

        let regionOffset = range.location

        // Parse with cmark-gfm
        guard let doc = regionText.withCString({ cstr in
            cmark_parse_document(cstr, strlen(cstr), CMARK_OPT_DEFAULT)
        }) else {
            return []
        }
        defer { cmark_node_free(doc) }

        // Walk the AST and build blocks
        var blocks: [BlockModel] = []
        walkBlocks(node: doc, regionOffset: regionOffset, idGenerator: idGenerator, blocks: &blocks)
        return blocks
    }

    // MARK: - AST Walking

    private func walkBlocks(
        node: OpaquePointer,
        regionOffset: Int,
        idGenerator: BlockIDGenerator,
        blocks: inout [BlockModel]
    ) {
        var child = cmark_node_first_child(node)
        while let current = child {
            let nodeType = cmark_node_get_type(current)
            if let block = buildBlock(node: current, nodeType: nodeType, regionOffset: regionOffset, idGenerator: idGenerator) {
                blocks.append(block)
            }
            child = cmark_node_next(current)
        }
    }

    private func buildBlock(
        node: OpaquePointer,
        nodeType: cmark_node_type,
        regionOffset: Int,
        idGenerator: BlockIDGenerator
    ) -> BlockModel? {
        let kind: BlockKind
        var metadata = BlockMetadata()

        switch nodeType {
        case CMARK_NODE_HEADING:
            let level = Int(cmark_node_get_heading_level(node))
            kind = .heading(level: level)
            metadata.headingLevel = level

        case CMARK_NODE_PARAGRAPH:
            kind = .paragraph

        case CMARK_NODE_CODE_BLOCK:
            kind = .codeBlock
            if let fence = cmark_node_get_fence_info(node) {
                let lang = String(cString: fence)
                if !lang.isEmpty {
                    metadata.fenceLanguage = lang
                }
            }

        case CMARK_NODE_BLOCK_QUOTE:
            kind = .blockquote

        case CMARK_NODE_LIST:
            let listType = cmark_node_get_list_type(node)
            kind = listType == CMARK_ORDERED_LIST ? .orderedList : .unorderedList

        case CMARK_NODE_ITEM:
            kind = .listItem

        case CMARK_NODE_THEMATIC_BREAK:
            kind = .thematicBreak

        default:
            // Skip unsupported node types
            return nil
        }

        // Compute source range.
        // cmark line/column are 1-based. We use them to approximate byte ranges.
        let startLine = Int(cmark_node_get_start_line(node))
        let endLine = Int(cmark_node_get_end_line(node))
        let startCol = Int(cmark_node_get_start_column(node))
        let endCol = Int(cmark_node_get_end_column(node))

        // For now, store line/col info as a simple range approximation.
        // A precise mapping requires scanning the source text, which BlockBuilder handles.
        let sourceRange = NSRange(
            location: regionOffset + startLine,
            length: max(0, endLine - startLine + endCol - startCol)
        )

        // Collect inline spans
        var inlines: [InlineSpan] = []
        if nodeType == CMARK_NODE_PARAGRAPH || nodeType == CMARK_NODE_HEADING || nodeType == CMARK_NODE_ITEM {
            collectInlines(node: node, inlines: &inlines)
        }

        // Compute content hash
        let contentHash: UInt64
        if let literal = cmark_node_get_literal(node) {
            contentHash = fnv1a(String(cString: literal))
        } else {
            contentHash = fnv1a("\(kind):\(startLine):\(endLine)")
        }

        return BlockModel(
            id: idGenerator.next(),
            kind: kind,
            range: sourceRange,
            inlines: inlines,
            metadata: metadata,
            contentHash: contentHash
        )
    }

    private func collectInlines(node: OpaquePointer, inlines: inout [InlineSpan]) {
        var child = cmark_node_first_child(node)
        while let current = child {
            let nodeType = cmark_node_get_type(current)

            let inlineKind: InlineKind?
            var text = ""

            switch nodeType {
            case CMARK_NODE_TEXT:
                inlineKind = .text
                if let literal = cmark_node_get_literal(current) {
                    text = String(cString: literal)
                }

            case CMARK_NODE_EMPH:
                inlineKind = .emphasis
                text = collectLiteralText(node: current)

            case CMARK_NODE_STRONG:
                inlineKind = .strong
                text = collectLiteralText(node: current)

            case CMARK_NODE_CODE:
                inlineKind = .code
                if let literal = cmark_node_get_literal(current) {
                    text = String(cString: literal)
                }

            case CMARK_NODE_LINK:
                let dest: String
                if let url = cmark_node_get_url(current) {
                    dest = String(cString: url)
                } else {
                    dest = ""
                }
                inlineKind = .link(destination: dest)
                text = collectLiteralText(node: current)

            case CMARK_NODE_SOFTBREAK:
                inlineKind = .softBreak
                text = "\n"

            case CMARK_NODE_LINEBREAK:
                inlineKind = .lineBreak
                text = "\n"

            default:
                inlineKind = nil
                // Recurse into unknown container nodes
                collectInlines(node: current, inlines: &inlines)
            }

            if let kind = inlineKind {
                let startLine = Int(cmark_node_get_start_line(current))
                let startCol = Int(cmark_node_get_start_column(current))
                let span = InlineSpan(
                    kind: kind,
                    range: NSRange(location: startLine * 1000 + startCol, length: text.utf16.count),
                    text: text
                )
                inlines.append(span)
            }

            child = cmark_node_next(current)
        }
    }

    /// Recursively collect all literal text from a node's children.
    private func collectLiteralText(node: OpaquePointer) -> String {
        var result = ""
        var child = cmark_node_first_child(node)
        while let current = child {
            if let literal = cmark_node_get_literal(current) {
                result += String(cString: literal)
            }
            result += collectLiteralText(node: current)
            child = cmark_node_next(current)
        }
        return result
    }
}

// MARK: - FNV-1a Hash

/// Simple FNV-1a hash for content-based cache keys.
func fnv1a(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    return hash
}
