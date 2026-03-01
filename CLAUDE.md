# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
./run.sh              # swift build && swift run HelloNotch
swift build           # build only
swift run HelloNotch  # run only
```

Swift Package Manager project (Package.swift), macOS 14+, Swift 5.10. There is also an `.xcodeproj` but SPM is the primary build system.

## Architecture

Menu-bar-only macOS app (LSUIElement) that displays reminder notifications as an overlay panel sliding down from the screen's notch area.

**Flow:** `HelloNotchApp` → `AppDelegate` (status bar menu) → `OverlayController` (animation + state) → `OverlayPanel` (NSPanel) + `NotchView` (SwiftUI)

**Key components:**
- `ScreenResolver` — detects physical notch via `auxiliaryTopLeftArea/auxiliaryTopRightArea`, falls back to centered 185pt virtual notch on non-notch screens. Returns `NotchInfo` with `hasHardwareNotch` flag
- `OverlayController` — manages panel lifecycle, frame-based height animation (42 steps, 0.35s cubic ease), auto-hide/re-show cycle, click/hover handlers
- `OverlayPanel` — borderless NSPanel at `.statusBar` level, stationary, transparent
- `NotchView` — multi-layer SwiftUI view: soft edge fringe, solid black body, hover glows, shimmer, text, action labels. Shape is `UnevenRoundedRectangle` (flat top, rounded bottom)
- `ReminderStore` — JSON persistence to `~/Library/Application Support/HelloNotch/reminders.json`. Supports one-time, interval-recurring, and weekday-scheduled reminders
- `AddReminderView` — modal panels for add/list reminders with custom flat dark UI components

**Two notch modes:**
- Hardware notch: 54pt height, calibrated offsets for MacBook Pro 14"
- Virtual notch (external monitors): 30pt height, centered on screen

## Conventions

- All UI controllers are `@MainActor`
- Config constants centralized in `Config.swift`
- Frame-based animation (not SwiftUI animation) for the panel height — uses `Task.sleep` loop with cubic easing
- Color hex initializer on `Color` in `NotchView.swift`

- Use English in code and coments and respond with the language you are asked
