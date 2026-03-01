import Foundation

enum Config {
    // Calibrated manually: panel height when expanded over the notch area.
    // 54pt for hardware notch (MacBook Pro 14"), 30pt for external monitors.
    static let expandedHeight: CGFloat = 54
    static let expandedHeightNoNotch: CGFloat = 27
    static let cornerRadius: CGFloat = 10
    // Action labels (Done/Later) pinned 14pt from bottom edge of the notch.
    // Works for both heights: 54pt → labels at 40pt, 30pt → labels at 16pt.
    static let labelsBottomInset: CGFloat = 14
    static let autoHideSeconds: TimeInterval = 10.0

    // Calibrated manually on MacBook Pro 14" (1512x982) to align panel
    // with the physical notch. The API-reported notch rect is ~1pt wider
    // than the visible notch, so we shrink width by 1pt and shift right
    // by 1pt to compensate.
    // TODO: These offsets may differ on 16" MacBook Pro / MacBook Air.
    //       Consider adding a per-model calibration or user-adjustable
    //       offset slider in Settings for fine-tuning on other screens.
    static let notchXOffset: CGFloat = 1
    static let notchWidthShrink: CGFloat = 1

    // Soft semi-transparent fringe extending beyond the solid black panel
    // on each side, for a seamless blend with the physical notch edge.
    static let softEdgeExtent: CGFloat = 0.5
    static let softEdgeOpacity: Double = 0.2

    // Inverted (concave) outer corners for virtual notch on non-notch screens
    static let outerCornerRadius: CGFloat = 6

    // Hover zone highlight colors
    static let hoverGreenColor = "00DD00"
    static let hoverRedColor = "DD0000"
    static let hoverOpacity: Double = 0.12
}
