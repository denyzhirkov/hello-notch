import AppKit
import SwiftUI

@MainActor
final class OverlayController {

    private var panel: OverlayPanel?
    private var hostingView: NSHostingView<NotchView>?
    private var autoHideTimer: Timer?
    private var animationTask: Task<Void, Never>?
    private var currentNotch: NotchInfo?

    let store = ReminderStore()
    private var currentReminder: Reminder?
    private var dueCheckTimer: Timer?

    // MARK: - Setup

    func setup() {
        let screen = ScreenResolver.activeScreen()
        let notch = ScreenResolver.notchInfo(on: screen)
        let frame = ScreenResolver.panelFrame(height: 0, notch: notch)

        let panel = OverlayPanel(contentRect: frame)

        let hostingView = NSHostingView(
            rootView: NotchView(message: "", pulseID: UUID())
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
        self.currentNotch = notch

        panel.orderFrontRegardless()
        panel.alphaValue = 0

        startDueCheckTimer()
    }

    private func startDueCheckTimer() {
        dueCheckTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
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
        updateView(message: message)

        let screen = ScreenResolver.activeScreen()
        let notch = ScreenResolver.notchInfo(on: screen)
        currentNotch = notch

        panel?.alphaValue = 1
        panel?.ignoresMouseEvents = false

        animateHeight(to: Config.expandedHeight, notch: notch)
        scheduleAutoHide()
    }

    /// Show the next pending reminder, or hide if none left.
    func showNextReminder() {
        if let reminder = store.next() {
            currentReminder = reminder
            showPulse(message: reminder.text)
        } else {
            currentReminder = nil
            hide()
        }
    }

    func hide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        currentReminder = nil

        let screen = ScreenResolver.activeScreen()
        let notch = ScreenResolver.notchInfo(on: screen)
        animateHeight(to: 0, notch: notch) { [weak self] in
            self?.panel?.alphaValue = 0
            self?.panel?.ignoresMouseEvents = true
        }
    }

    // MARK: - Click handlers

    private func handleLeftClick() {
        guard let reminder = currentReminder else { return }
        store.markDone(id: reminder.id)
        showNextReminder()
    }

    private func handleRightClick() {
        hide()
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
                self?.hide()
            }
        }
    }

    private func updateView(message: String) {
        hostingView?.rootView = NotchView(
            message: message,
            pulseID: UUID(),
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
        notch: NotchInfo,
        completion: (() -> Void)? = nil
    ) {
        animationTask?.cancel()

        let startHeight = panel?.frame.height ?? 0
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
                let frame = ScreenResolver.panelFrame(height: h, notch: notch)
                panel?.setFrame(frame, display: true)

                if i < steps {
                    try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                }
            }
            completion?()
        }
    }
}
