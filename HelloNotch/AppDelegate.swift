import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let overlayController = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayController.setup()
        setupStatusBar()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: "HelloNotch"
            )
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: "Test Pulse", action: #selector(testPulse), keyEquivalent: "t")
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
    }

    @objc private func testPulse() {
        overlayController.showPulse(message: "New item")
    }
}
