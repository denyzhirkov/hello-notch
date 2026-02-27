import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let overlayController = OverlayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
            NSMenuItem(title: "Add Reminder...", action: #selector(addReminder), keyEquivalent: "n")
        )
        menu.addItem(
            NSMenuItem(title: "Show Reminders", action: #selector(showReminders), keyEquivalent: "r")
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Test Pulse", action: #selector(testPulse), keyEquivalent: "t")
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
    }

    @objc private func addReminder() {
        showAddReminderPanel { [weak self] text, fireDate, recurringInterval, weekdays in
            self?.overlayController.store.add(
                text: text,
                fireDate: fireDate,
                recurringInterval: recurringInterval,
                recurringWeekdays: weekdays
            )
        }
    }

    @objc private func showReminders() {
        showRemindersListPanel(store: overlayController.store)
    }

    @objc private func testPulse() {
        overlayController.showPulse(message: "New item")
    }
}
