import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    private var windowController: EditorWindowController?

    private func launchLog(_ message: String) {
        let line = "[BarrelLaunch] \(message)"
        print(line)
        NSLog("%@", line)

        let logURL = URL(fileURLWithPath: "/tmp/barrel-launch.log")
        let payload = "\(line)\n"
        if let data = payload.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    defer { try? handle.close() }
                    handle.seekToEndOfFile()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: logURL, options: .atomic)
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchLog("applicationWillFinishLaunching")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchLog("applicationDidFinishLaunching begin")
        // Create the main editor window
        let windowController = EditorWindowController()
        self.windowController = windowController
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        launchLog("applicationDidFinishLaunching end; visible=\(windowController.window?.isVisible == true)")
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
