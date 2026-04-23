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
    private var animationTask: Task<Void, Never>?

    /// Blocks automatic reshow of the same due reminder until this moment passes.
    /// Set by autoHide to Date()+reshowSuppressWindow; cleared by explicit dismiss.
    private var suppressReshowUntil: Date?
    private static let reshowSuppressWindow: TimeInterval = 10

    let store = ReminderStore()
    private var currentReminder: Reminder?
    private var dueCheckTimer: Timer?

    private var observerTokens: [NSObjectProtocol] = []

    deinit {
        dueCheckTimer?.invalidate()
        autoHideTimer?.invalidate()
        animationTask?.cancel()
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    // MARK: - Setup

    func setup() {
        rebuildPanels()

        let screenToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildPanels()
            }
        }
        observerTokens.append(screenToken)

        // Timers freeze during system sleep; kick a check immediately on wake
        // so the first due reminder surfaces without waiting up to 5s.
        let wakeToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkDueReminders()
            }
        }
        observerTokens.append(wakeToken)

        startDueCheckTimer()
    }

    private func rebuildPanels() {
        // Any in-flight state references soon-to-be-destroyed entries.
        resetOverlayState()

        for entry in entries.values {
            entry.panel.orderOut(nil)
        }
        entries.removeAll()

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

    /// Clears every piece of overlay state so nothing references stale entries.
    /// Safe to call multiple times.
    private func resetOverlayState() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        animationTask?.cancel()
        animationTask = nil
        currentReminder = nil
        activeDisplayID = nil
        suppressReshowUntil = nil
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func startDueCheckTimer() {
        dueCheckTimer = Timer.scheduledTimer(
            withTimeInterval: Config.dueCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkDueReminders()
            }
        }
    }

    private func checkDueReminders() {
        guard currentReminder == nil else { return }
        if let until = suppressReshowUntil, Date() < until { return }
        suppressReshowUntil = nil
        guard let due = store.dueReminders().first else { return }
        presentReminder(due)
    }

    // MARK: - Public API

    /// Message-only pulse (debug / ad-hoc). Does not touch `currentReminder`.
    func showPulse(message: String = "New item") {
        _ = presentOverlay(message: message)
    }

    /// Show the next due reminder, or hide if none left.
    func showNextReminder() {
        if let reminder = store.dueReminders().first {
            presentReminder(reminder)
        } else {
            dismiss()
        }
    }

    // MARK: - Presentation

    /// Attempt to show a reminder. Sets `currentReminder` only on success.
    private func presentReminder(_ reminder: Reminder) {
        if presentOverlay(message: reminder.text) {
            currentReminder = reminder
        }
    }

    /// Resolves the target screen, configures the panel, and kicks off the show animation.
    /// Returns false if no overlay could be shown (caller must NOT mutate currentReminder).
    @discardableResult
    private func presentOverlay(message: String) -> Bool {
        autoHideTimer?.invalidate()

        let screen = ScreenResolver.activeScreen()
        guard let targetID = displayID(for: screen),
              let entry = entries[targetID] else { return false }

        if let prevID = activeDisplayID, prevID != targetID, let prevEntry = entries[prevID] {
            animationTask?.cancel()
            let zeroFrame = ScreenResolver.panelFrame(height: 0, notch: prevEntry.notch)
            prevEntry.panel.setFrame(zeroFrame, display: false)
            prevEntry.panel.alphaValue = 0
            prevEntry.panel.ignoresMouseEvents = true
        }

        activeDisplayID = targetID

        // Hardware notch: start panel at physical notch height so it blends
        // with the real notch before expanding — gives "notch grows" illusion.
        let startH: CGFloat = entry.notch.hasHardwareNotch ? entry.notch.notchHeight : 0
        entry.panel.setFrame(ScreenResolver.panelFrame(height: startH, notch: entry.notch), display: false)

        updateView(message: message, entry: entry)

        entry.panel.alphaValue = 1
        entry.panel.ignoresMouseEvents = false

        let height = entry.notch.hasHardwareNotch ? Config.expandedHeight : Config.expandedHeightNoNotch
        animateHeight(to: height, entry: entry)
        scheduleAutoHide()
        return true
    }

    /// Hard dismiss — explicit user action, no reshow suppression window.
    private func dismiss() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        currentReminder = nil
        suppressReshowUntil = nil
        collapsePanel()
    }

    /// Soft hide — starts suppression window so the same reminder doesn't instantly re-pop.
    private func autoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        let hadPending = currentReminder != nil
        currentReminder = nil
        if hadPending {
            suppressReshowUntil = Date().addingTimeInterval(Self.reshowSuppressWindow)
        }
        collapsePanel()
    }

    private func collapsePanel() {
        guard let id = activeDisplayID, let entry = entries[id] else {
            activeDisplayID = nil
            return
        }
        // Hardware notch: animate back to physical notch size, then snap invisible
        // so the panel merges seamlessly with the real notch before disappearing.
        let collapseTarget: CGFloat = entry.notch.hasHardwareNotch ? entry.notch.notchHeight : 0
        animateHeight(to: collapseTarget, entry: entry) { [weak self] in
            entry.panel.alphaValue = 0
            entry.panel.ignoresMouseEvents = true
            if entry.notch.hasHardwareNotch {
                entry.panel.setFrame(
                    ScreenResolver.panelFrame(height: 0, notch: entry.notch),
                    display: false
                )
            }
            self?.activeDisplayID = nil
        }
    }

    // MARK: - Click handlers

    private func handleLeftClick() {
        guard let reminder = currentReminder else { return }
        store.markDone(id: reminder.id)
        currentReminder = nil
        showNextReminder()
    }

    private func handleRightClick() {
        // Fall back to first due if currentReminder was cleared by a racing autoHide.
        let target = currentReminder ?? store.dueReminders().first
        if let reminder = target {
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
        autoHideTimer = nil
        // "Keep until clicked" mode: panel stays until an explicit click action.
        if Config.keepUntilClicked { return }
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

        if !entry.notch.hasHardwareNotch {
            animateSlide(expanding: targetHeight > 0, entry: entry, completion: completion)
            return
        }

        let startHeight = entry.panel.frame.height
        let expanding = targetHeight > startHeight
        let startWidthScale: CGFloat = expanding ? 1.0 : 1.1
        let endWidthScale: CGFloat = expanding ? 1.1 : 1.0
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
                let scale = startWidthScale + (endWidthScale - startWidthScale) * CGFloat(t)
                let base = ScreenResolver.panelFrame(height: h, notch: entry.notch)
                let ear = Config.outerCornerRadius
                let scaledBody = (base.width - 2 * ear) * scale
                let scaledWidth = scaledBody + 2 * ear
                let frame = NSRect(
                    x: base.midX - scaledWidth / 2,
                    y: base.minY,
                    width: scaledWidth,
                    height: base.height
                )
                entry.panel.setFrame(frame, display: true)

                if i < steps {
                    try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                }
            }
            completion?()
        }
    }

    // Slide the virtual notch panel in/out by animating Y position.
    // Panel stays full-height so all corners are always correctly rendered;
    // the screen edge acts as a natural clip as it slides from above.
    private func animateSlide(
        expanding: Bool,
        entry: ScreenEntry,
        completion: (() -> Void)? = nil
    ) {
        let fullHeight = Config.expandedHeightNoNotch
        let ear = Config.outerCornerRadius
        let baseX = entry.notch.x - ear
        let baseW = entry.notch.width + 2 * ear
        let startY: CGFloat = expanding
            ? entry.notch.screenMaxY              // above screen
            : entry.notch.screenMaxY - fullHeight // visible
        let endY: CGFloat = expanding
            ? entry.notch.screenMaxY - fullHeight // visible
            : entry.notch.screenMaxY              // above screen
        let startWidthScale: CGFloat = expanding ? 1.0 : 1.1
        let endWidthScale: CGFloat = expanding ? 1.1 : 1.0
        let duration: Double = 0.35
        let steps = 42

        animationTask = Task {
            for i in 0...steps {
                guard !Task.isCancelled else { return }

                let progress = Double(i) / Double(steps)
                let t = progress < 0.5
                    ? 4 * progress * progress * progress
                    : 1 - pow(-2 * progress + 2, 3) / 2

                let y = startY + (endY - startY) * t
                let scale = startWidthScale + (endWidthScale - startWidthScale) * CGFloat(t)
                let ear = Config.outerCornerRadius
                let scaledBody = (baseW - 2 * ear) * scale
                let w = scaledBody + 2 * ear
                let x = baseX + (baseW - w) / 2
                entry.panel.setFrame(NSRect(x: x, y: y, width: w, height: fullHeight), display: true)

                if i < steps {
                    try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                }
            }
            completion?()
        }
    }
}
