import Foundation
import MarkdownCore

#if canImport(AppKit)
import AppKit
#endif

// MARK: - LayoutEngine

/// Computes `LayoutBlock` from `BlockModel` given width and theme constraints.
///
/// This is a pure computation — no UI side effects. It can run on any thread.
///
/// For Stage 1, layout produces `NSAttributedString` payloads.
/// For Stage 2, it would produce CoreText frames.
public struct LayoutEngine: Sendable {

    public init() {}

    /// Lay out a single block.
    ///
    /// - Parameters:
    ///   - block: The block model to lay out.
    ///   - width: Available width for layout.
    ///   - theme: The current theme style.
    /// - Returns: A `LayoutBlock` with measured height and draw payload.
    public func layout(
        block: BlockModel,
        width: CGFloat,
        theme: ThemeStyle
    ) -> LayoutBlock {
        let attributedString = buildAttributedString(block: block, theme: theme)
        let height = measureHeight(attributedString: attributedString, width: width)

        return LayoutBlock(
            id: block.id,
            measuredHeight: height + theme.paragraphSpacing,
            sourceRange: block.range,
            kind: block.kind,
            drawPayload: .attributedString(attributedString)
        )
    }

    /// Lay out multiple blocks. Only lays out blocks not already in the cache.
    public func layoutBlocks(
        _ blocks: [BlockModel],
        width: CGFloat,
        theme: ThemeStyle,
        cache: inout LayoutCache
    ) -> [LayoutBlock] {
        blocks.map { block in
            let key = LayoutKey(
                blockID: block.id,
                width: width,
                themeVariant: theme.variant,
                contentHash: block.contentHash
            )

            if let cached = cache.get(key: key) {
                return cached
            }

            let layoutBlock = layout(block: block, width: width, theme: theme)
            cache.set(key: key, value: layoutBlock)
            return layoutBlock
        }
    }

    // MARK: - Attributed String Building

    /// Build an `NSAttributedString` for a block based on its kind and inlines.
    func buildAttributedString(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        switch block.kind {
        case .heading(let level):
            return buildHeading(block: block, level: level, theme: theme)
        case .paragraph:
            return buildParagraph(block: block, theme: theme)
        case .codeBlock:
            return buildCodeBlock(block: block, theme: theme)
        case .blockquote:
            return buildBlockquote(block: block, theme: theme)
        case .thematicBreak:
            return buildThematicBreak(theme: theme)
        case .orderedList, .unorderedList, .listItem:
            return buildListItem(block: block, theme: theme)
        case .document:
            return NSAttributedString()
        }
    }

    #if canImport(AppKit)
    private func buildHeading(block: BlockModel, level: Int, theme: ThemeStyle) -> NSAttributedString {
        let scaleIndex = min(level - 1, theme.headingScales.count - 1)
        let scale = theme.headingScales[max(0, scaleIndex)]
        let fontSize = theme.bodyFontSize * scale
        let font = NSFont.boldSystemFont(ofSize: fontSize)

        let text = block.inlines.map(\.text).joined()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.lineSpacing

        return NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ])
    }

    private func buildParagraph(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: theme.bodyFontSize)
        let codeFont = NSFont.monospacedSystemFont(ofSize: theme.codeFontSize, weight: .regular)

        for span in block.inlines {
            let attrs: [NSAttributedString.Key: Any]
            switch span.kind {
            case .text, .softBreak, .lineBreak:
                attrs = [.font: bodyFont]
            case .emphasis:
                attrs = [.font: NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)]
            case .strong:
                attrs = [.font: NSFont.boldSystemFont(ofSize: theme.bodyFontSize)]
            case .code:
                attrs = [.font: codeFont]
            case .link(let dest):
                attrs = [
                    .font: bodyFont,
                    .link: dest,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ]
            }
            result.append(NSAttributedString(string: span.text, attributes: attrs))
        }

        if result.length == 0 {
            result.append(NSAttributedString(string: " ", attributes: [.font: bodyFont]))
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.lineSpacing
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func buildCodeBlock(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: theme.codeFontSize, weight: .regular)
        let text = block.inlines.map(\.text).joined()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.lineSpacing

        return NSAttributedString(string: text.isEmpty ? " " : text, attributes: [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ])
    }

    private func buildBlockquote(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: theme.bodyFontSize)
        let text = block.inlines.map(\.text).joined()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.lineSpacing
        paragraphStyle.headIndent = theme.blockquoteIndent
        paragraphStyle.firstLineHeadIndent = theme.blockquoteIndent

        return NSAttributedString(string: text.isEmpty ? " " : text, attributes: [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ])
    }

    private func buildThematicBreak(theme: ThemeStyle) -> NSAttributedString {
        // Render as a thin line represented by a dashed string
        let font = NSFont.systemFont(ofSize: theme.bodyFontSize * 0.5)
        return NSAttributedString(string: "────────────────────────────────", attributes: [
            .font: font,
            .foregroundColor: NSColor.separatorColor,
        ])
    }

    private func buildListItem(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: theme.bodyFontSize)
        let text = block.inlines.map(\.text).joined()
        let depth = CGFloat(block.metadata.nestingDepth)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = theme.lineSpacing
        paragraphStyle.headIndent = theme.listIndent * (depth + 1)
        paragraphStyle.firstLineHeadIndent = theme.listIndent * depth

        let bullet: String
        switch block.kind {
        case .orderedList:
            bullet = "1. "
        case .unorderedList:
            bullet = "• "
        default:
            bullet = "• "
        }

        return NSAttributedString(string: bullet + (text.isEmpty ? " " : text), attributes: [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ])
    }

    private func measureHeight(attributedString: NSAttributedString, width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(attributedString: attributedString)
        let textContainer = NSTextContainer(containerSize: NSSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        return ceil(rect.height)
    }
    #else
    // Stubs for non-AppKit platforms (e.g., Linux CI). These should not be called in production.
    private func buildHeading(block: BlockModel, level: Int, theme: ThemeStyle) -> NSAttributedString {
        NSAttributedString(string: block.inlines.map(\.text).joined())
    }
    private func buildParagraph(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        NSAttributedString(string: block.inlines.map(\.text).joined())
    }
    private func buildCodeBlock(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        NSAttributedString(string: block.inlines.map(\.text).joined())
    }
    private func buildBlockquote(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        NSAttributedString(string: block.inlines.map(\.text).joined())
    }
    private func buildThematicBreak(theme: ThemeStyle) -> NSAttributedString {
        NSAttributedString(string: "---")
    }
    private func buildListItem(block: BlockModel, theme: ThemeStyle) -> NSAttributedString {
        NSAttributedString(string: block.inlines.map(\.text).joined())
    }
    private func measureHeight(attributedString: NSAttributedString, width: CGFloat) -> CGFloat {
        // Approximate: 20pt per line, estimate lines from character count
        let charsPerLine = max(1, Int(width / 8))
        let lines = max(1, attributedString.length / charsPerLine)
        return CGFloat(lines) * 20.0
    }
    #endif
}
