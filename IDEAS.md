# Ideas

## Wake/Login Summary Notification

On wake, screen wake, or user session start — show a brief summary in the notch overlay.

Examples: "3 reminders today", "No plans today", "2 events, 1 reminder".

### Implementation notes

- Hook: `NSWorkspace.didWakeNotification` already exists in `OverlayController`
- Show summary overlay first, then transition to first due reminder after a few seconds
- Deduplicate by date — avoid repeat summary if launchd restarts the app multiple times on the same wake (SIGBUS recovery)

### Data sources

- **ReminderStore** (internal) — trivial, already available
- **Calendar.app** via `EventKit` — needs `EKEventStore.requestFullAccessToEvents()` + `NSCalendarsFullAccessUsageDescription` in Info.plist
