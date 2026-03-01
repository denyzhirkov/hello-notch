import AppKit
import SwiftUI

@MainActor
final class OverlayController {

    private struct ScreenEntry {
        let panel: OverlayPanel
        let hostingView: NSHostingView<NotchView>
        let notch: NotchInfo
        let displayID: CGDirectDisplayID
    }

    private var entries: [CGDirectDisplayID: ScreenEntry] = [:]
    private var activeDisplayID: CGDirectDisplayID?

    private var autoHideTimer: Timer?
    private var reshowTimer: Timer?
    private var animationTask: Task<Void, Never>?

    let store = ReminderStore()
    private var currentReminder: Reminder?
    private var dueCheckTimer: Timer?

    deinit {
        dueCheckTimer?.invalidate()
        autoHideTimer?.invalidate()
        reshowTimer?.invalidate()
        animationTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    func setup() {
        rebuildPanels()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildPanels()
            }
        }

        startDueCheckTimer()
    }

    private func rebuildPanels() {
        // Collapse and remove all existing panels
        animationTask?.cancel()
        animationTask = nil
        for entry in entries.values {
            entry.panel.orderOut(nil)
        }
        entries.removeAll()
        activeDisplayID = nil

        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen) else { continue }

            let notch = ScreenResolver.notchInfo(on: screen)
            let frame = ScreenResolver.panelFrame(height: 0, notch: notch)

            let panel = OverlayPanel(contentRect: frame)

            let hostingView = NSHostingView(
                rootView: NotchView(message: "", pulseID: UUID(), hasHardwareNotch: notch.hasHardwareNotch)
            )
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear

            panel.contentView = hostingView
            panel.orderFrontRegardless()
            panel.alphaValue = 0

            entries[displayID] = ScreenEntry(
                panel: panel,
                hostingView: hostingView,
                notch: notch,
                displayID: displayID
            )
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func startDueCheckTimer() {
        dueCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 5,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkDueReminders()
            }
        }
    }

    private func checkDueReminders() {
        guard currentReminder == nil else { return }
        if let due = store.dueReminders().first {
            currentReminder = due
            showPulse(message: due.text)
        }
    }

    // MARK: - Public API

    func showPulse(message: String = "New item") {
        autoHideTimer?.invalidate()
        reshowTimer?.invalidate()

        let screen = ScreenResolver.activeScreen()
        guard let targetID = displayID(for: screen),
              let entry = entries[targetID] else { return }

        // If a different panel was active, collapse it immediately
        if let prevID = activeDisplayID, prevID != targetID, let prevEntry = entries[prevID] {
            animationTask?.cancel()
            let zeroFrame = ScreenResolver.panelFrame(height: 0, notch: prevEntry.notch)
            prevEntry.panel.setFrame(zeroFrame, display: false)
            prevEntry.panel.alphaValue = 0
            prevEntry.panel.ignoresMouseEvents = true
        }

        activeDisplayID = targetID

        // Reset panel to zero height on the target screen before showing
        let zeroFrame = ScreenResolver.panelFrame(height: 0, notch: entry.notch)
        entry.panel.setFrame(zeroFrame, display: false)

        updateView(message: message, entry: entry)

        entry.panel.alphaValue = 1
        entry.panel.ignoresMouseEvents = false

        let height = entry.notch.hasHardwareNotch ? Config.expandedHeight : Config.expandedHeightNoNotch
        animateHeight(to: height, entry: entry)
        scheduleAutoHide()
    }

    /// Show the next pending reminder, or hide if none left.
    func showNextReminder() {
        if let reminder = store.next() {
            currentReminder = reminder
            showPulse(message: reminder.text)
        } else {
            currentReminder = nil
            dismiss()
        }
    }

    /// Hard dismiss — no re-show. Used by explicit user actions.
    private func dismiss() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        reshowTimer?.invalidate()
        reshowTimer = nil
        currentReminder = nil
        collapsePanel()
    }

    /// Soft hide — collapses panel, schedules re-show if reminder is still due.
    private func autoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        let pending = currentReminder
        currentReminder = nil
        collapsePanel()

        // Schedule re-show in 10s if the reminder is still due
        if pending != nil {
            reshowTimer?.invalidate()
            reshowTimer = Timer.scheduledTimer(
                withTimeInterval: 10,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.checkDueReminders()
                }
            }
        }
    }

    private func collapsePanel() {
        guard let id = activeDisplayID, let entry = entries[id] else { return }
        animateHeight(to: 0, entry: entry) { [weak self] in
            entry.panel.alphaValue = 0
            entry.panel.ignoresMouseEvents = true
            self?.activeDisplayID = nil
        }
    }

    // MARK: - Click handlers

    private func handleLeftClick() {
        guard let reminder = currentReminder else { return }
        store.markDone(id: reminder.id)
        showNextReminder()
    }

    private func handleRightClick() {
        if let reminder = currentReminder {
            store.snooze(id: reminder.id)
        }
        dismiss()
    }

    // MARK: - View update

    private func handleHover(_ hovering: Bool) {
        if hovering {
            autoHideTimer?.invalidate()
            autoHideTimer = nil
        } else {
            scheduleAutoHide()
        }
    }

    private func scheduleAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = Timer.scheduledTimer(
            withTimeInterval: Config.autoHideSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.autoHide()
            }
        }
    }

    private func updateView(message: String, entry: ScreenEntry) {
        entry.hostingView.rootView = NotchView(
            message: message,
            pulseID: UUID(),
            hasHardwareNotch: entry.notch.hasHardwareNotch,
            onLeft: { [weak self] in
                Task { @MainActor in self?.handleLeftClick() }
            },
            onRight: { [weak self] in
                Task { @MainActor in self?.handleRightClick() }
            },
            onHoverChanged: { [weak self] hovering in
                Task { @MainActor in self?.handleHover(hovering) }
            }
        )
    }

    // MARK: - Animation

    private func animateHeight(
        to targetHeight: CGFloat,
        entry: ScreenEntry,
        completion: (() -> Void)? = nil
    ) {
        animationTask?.cancel()

        let startHeight = entry.panel.frame.height
        let duration: Double = 0.35
        let steps = 42 // ~120fps over 0.35s

        animationTask = Task {
            for i in 0...steps {
                guard !Task.isCancelled else { return }

                let progress = Double(i) / Double(steps)
                // ease-in-out cubic
                let t = progress < 0.5
                    ? 4 * progress * progress * progress
                    : 1 - pow(-2 * progress + 2, 3) / 2

                let h = startHeight + (targetHeight - startHeight) * t
                let frame = ScreenResolver.panelFrame(height: h, notch: entry.notch)
                entry.panel.setFrame(frame, display: true)

                if i < steps {
                    try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                }
            }
            completion?()
        }
    }
}
