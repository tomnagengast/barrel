import AppKit
import MarkdownCore
import MarkdownLayout
import MarkdownRender

// MARK: - PreviewViewController

/// The preview pane. Stage 1: read-only NSTextView with block-level splices.
final class PreviewViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var textView: NSTextView!

    /// The renderer that applies preview diffs to this view.
    private(set) var renderer: TextKitPreviewRenderer?

    // MARK: - Lifecycle

    override func loadView() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder

        let contentSize = scrollView.contentSize
        let textContainer = NSTextContainer(containerSize: NSSize(
            width: contentSize.width,
            height: .greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.backgroundColor = .textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 16, height: 16)

        scrollView.documentView = textView
        self.scrollView = scrollView
        self.textView = textView
        self.view = scrollView

        // Create the renderer backed by this text view's storage
        self.renderer = TextKitPreviewRenderer(textStorage: textStorage)
    }

    /// The width available for layout (accounts for text container inset).
    var availableWidth: CGFloat {
        guard let textView = textView else { return 600 }
        return textView.textContainer?.containerSize.width ?? textView.bounds.width - 32
    }
}
