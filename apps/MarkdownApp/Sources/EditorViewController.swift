import AppKit
import MarkdownCore

// MARK: - EditorViewController

/// The source editor pane. Uses NSTextView with TextKit 1 for predictable
/// text editing performance.
final class EditorViewController: NSViewController, NSTextStorageDelegate {

    /// The coordinator that receives edit events and dispatches background work.
    weak var coordinator: LayoutCoordinator?

    private var scrollView: NSScrollView!
    private var textView: NSTextView!

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
        textStorage.delegate = self

        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        self.scrollView = scrollView
        self.textView = textView
        self.view = scrollView
    }

    // MARK: - File I/O

    /// Load a file into the editor.
    func loadFile(at url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        textView.string = string
        // Trigger an initial full parse
        coordinator?.documentDidLoad(text: textView.string as NSString)
    }

    /// Save the current content to a file (atomic write).
    func saveFile(to url: URL) throws {
        let text = textView.string
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    // MARK: - NSTextStorageDelegate

    /// Called after every edit. This is the HOT PATH entry point.
    ///
    /// We record the edit into the coordinator and return immediately.
    /// No parsing, no layout, no preview work happens here.
    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        // Only respond to actual text changes, not attribute-only changes
        guard editedMask.contains(.editedCharacters) else { return }

        coordinator?.recordEdit(
            editedRange: editedRange,
            changeInLength: delta,
            currentText: textStorage.string as NSString
        )
    }
}
