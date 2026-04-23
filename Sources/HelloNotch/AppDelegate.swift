import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let overlayController = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerLaunchAgent()
        overlayController.setup()
        setupStatusBar()
    }

    private func registerLaunchAgent() {
        let service = SMAppService.agent(plistName: "com.hellonotch.app.launcher.plist")
        guard service.status == .notRegistered else { return }
        try? service.register()
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
            NSMenuItem(title: "Add Reminder...", action: #selector(addReminder), keyEquivalent: "n")
        )
        menu.addItem(
            NSMenuItem(title: "Show Reminders", action: #selector(showReminders), keyEquivalent: "r")
        )
        menu.addItem(.separator())
        #if DEBUG
        menu.addItem(
            NSMenuItem(title: "Test Pulse", action: #selector(testPulse), keyEquivalent: "t")
        )
        menu.addItem(.separator())
        #endif
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
    }

    @objc private func addReminder() {
        showRemindersPanel(store: overlayController.store, initialMode: .add)
    }

    @objc private func showReminders() {
        showRemindersPanel(store: overlayController.store, initialMode: .list)
    }

    @objc private func openSettings() {
        showSettingsPanel()
    }

    #if DEBUG
    @objc private func testPulse() {
        overlayController.showPulse(message: "New item")
    }
    #endif
}
