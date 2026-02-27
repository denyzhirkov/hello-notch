import AppKit

enum ScreenResolver {

    /// Returns the screen that currently contains the mouse cursor.
    static func activeScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    /// Computes a window frame pinned to the top-center of the given screen.
    static func panelFrame(width: CGFloat, height: CGFloat, on screen: NSScreen) -> NSRect {
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
