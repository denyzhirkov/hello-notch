import AppKit

struct NotchInfo {
    let width: CGFloat
    let x: CGFloat          // global X of notch left edge
    let screenMaxY: CGFloat // top edge of screen (global)
    let hasHardwareNotch: Bool
}

enum ScreenResolver {

    static func activeScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }

    /// Detects notch geometry using auxiliaryTopLeftArea / auxiliaryTopRightArea.
    /// Falls back to a centered 185pt estimate if the screen has no notch.
    static func notchInfo(on screen: NSScreen) -> NotchInfo {
        if let topLeft = screen.auxiliaryTopLeftArea,
           let topRight = screen.auxiliaryTopRightArea {
            let notchLeft = screen.frame.origin.x + topLeft.maxX
            let notchRight = screen.frame.origin.x + topRight.minX
            let width = notchRight - notchLeft
            return NotchInfo(
                width: width,
                x: notchLeft,
                screenMaxY: screen.frame.maxY,
                hasHardwareNotch: true
            )
        }
        // Fallback for screens without notch
        let fallbackWidth: CGFloat = 185
        return NotchInfo(
            width: fallbackWidth,
            x: screen.frame.midX - fallbackWidth / 2,
            screenMaxY: screen.frame.maxY,
            hasHardwareNotch: false
        )
    }

    /// Panel frame pinned to notch position, growing downward.
    /// Offset and width calibrated manually (see Config).
    static func panelFrame(height: CGFloat, notch: NotchInfo) -> NSRect {
        if notch.hasHardwareNotch {
            return NSRect(
                x: notch.x + Config.notchXOffset,
                y: notch.screenMaxY - height,
                width: notch.width - Config.notchWidthShrink,
                height: height
            )
        } else {
            let ear = Config.outerCornerRadius
            return NSRect(
                x: notch.x - ear,
                y: notch.screenMaxY - height,
                width: notch.width + 2 * ear,
                height: height
            )
        }
    }
}
