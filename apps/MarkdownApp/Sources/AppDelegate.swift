import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the main editor window
        let windowController = EditorWindowController()
        windowController.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

// MARK: - EditorWindowController

final class EditorWindowController: NSWindowController {

    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 1200, height: 800)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .miniaturizable]
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "Barrel"
        window.center()
        window.setFrameAutosaveName("BarrelMainWindow")

        super.init(window: window)

        // Set up the split view with editor and preview
        let splitViewController = NSSplitViewController()

        let editorVC = EditorViewController()
        let editorItem = NSSplitViewItem(viewController: editorVC)
        editorItem.minimumThickness = 300
        editorItem.holdingPriority = .defaultLow

        let previewVC = PreviewViewController()
        let previewItem = NSSplitViewItem(viewController: previewVC)
        previewItem.minimumThickness = 300
        previewItem.holdingPriority = .defaultLow

        splitViewController.addSplitViewItem(editorItem)
        splitViewController.addSplitViewItem(previewItem)

        window.contentViewController = splitViewController

        // Wire up the coordinator
        let coordinator = LayoutCoordinator(
            editorViewController: editorVC,
            previewViewController: previewVC
        )
        editorVC.coordinator = coordinator
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
