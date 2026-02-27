import AppKit
import SwiftUI

@MainActor
final class OverlayController {

    private var panel: OverlayPanel?
    private var hostingView: NSHostingView<NotchView>?
    private var autoHideTimer: Timer?
    private var currentHeight: CGFloat = 0
    private var currentMessage: String = "New item"

    // MARK: - Setup

    func setup() {
        let screen = ScreenResolver.activeScreen()
        let frame = ScreenResolver.panelFrame(width: Config.panelWidth, height: 0, on: screen)

        let panel = OverlayPanel(contentRect: frame)
        let hostingView = NSHostingView(
            rootView: NotchView(message: currentMessage, height: 0)
        )
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        self.panel = panel
        self.hostingView = hostingView

        panel.orderFrontRegardless()
        panel.alphaValue = 0
    }

    // MARK: - Public API

    func showPulse(message: String = "New item") {
        currentMessage = message
        autoHideTimer?.invalidate()

        let screen = ScreenResolver.activeScreen()

        panel?.alphaValue = 1
        panel?.ignoresMouseEvents = false

        animateHeight(to: Config.expandedHeight, on: screen)

        autoHideTimer = Timer.scheduledTimer(
            withTimeInterval: Config.autoHideSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    func hide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil

        let screen = ScreenResolver.activeScreen()
        animateHeight(to: 0, on: screen) { [weak self] in
            self?.panel?.alphaValue = 0
            self?.panel?.ignoresMouseEvents = true
        }
    }

    // MARK: - Animation

    private func animateHeight(
        to targetHeight: CGFloat,
        on screen: NSScreen,
        completion: (() -> Void)? = nil
    ) {
        let frame = ScreenResolver.panelFrame(
            width: Config.panelWidth,
            height: targetHeight,
            on: screen
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel?.animator().setFrame(frame, display: true)
        } completionHandler: {
            completion?()
        }

        currentHeight = targetHeight
        hostingView?.rootView = NotchView(message: currentMessage, height: targetHeight)
    }
}
