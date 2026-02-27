import SwiftUI
import AppKit

// MARK: - Time Mode

enum ReminderTimeMode: String, CaseIterable {
    case atTime = "At time"
    case inInterval = "In..."
    case every = "Every"
}

enum TimeUnit: String, CaseIterable {
    case minutes = "min"
    case hours = "hours"

    var seconds: TimeInterval {
        switch self {
        case .minutes: return 60
        case .hours: return 3600
        }
    }
}

enum EveryMode: String, CaseIterable {
    case interval = "Interval"
    case schedule = "Schedule"
}

// MARK: - Flat TextField without focus ring

struct FlatTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.textColor = .white
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FlatTextField
        init(_ parent: FlatTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }
    }
}

// MARK: - Flat style helpers

struct FlatButtonStyle: ButtonStyle {
    var primary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: primary ? .semibold : .regular))
            .foregroundColor(primary ? .black : .white.opacity(0.8))
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
            .background(
                primary
                    ? Color.white.opacity(configuration.isPressed ? 0.8 : 1.0)
                    : Color.white.opacity(configuration.isPressed ? 0.12 : 0.07)
            )
            .cornerRadius(8)
    }
}

struct FlatSegmentPicker: View {
    @Binding var selection: ReminderTimeMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReminderTimeMode.allCases, id: \.self) { m in
                Button { selection = m } label: {
                    Text(m.rawValue)
                        .font(.system(size: 12, weight: selection == m ? .semibold : .regular))
                        .foregroundColor(selection == m ? .white : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selection == m
                                ? Color.white.opacity(0.12)
                                : Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Flat Date-Time Picker

struct FlatDateTimePicker: View {
    @Binding var date: Date

    private let cal = Calendar.current

    // Next 7 days starting from today
    private var days: [(label: String, date: Date)] {
        let today = cal.startOfDay(for: Date())
        let df = DateFormatter()
        df.dateFormat = "E d"
        return (0..<7).compactMap { offset -> (String, Date)? in
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let label: String
            switch offset {
            case 0: label = "Today"
            case 1: label = "Tmrw"
            default: label = df.string(from: d)
            }
            return (label, d)
        }
    }

    private var selectedDayStart: Date {
        cal.startOfDay(for: date)
    }

    private var hour: Int {
        get { cal.component(.hour, from: date) }
    }

    private var minute: Int {
        get { cal.component(.minute, from: date) }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Day chips
            HStack(spacing: 4) {
                ForEach(days, id: \.label) { day in
                    let isSelected = cal.isDate(day.date, inSameDayAs: date)
                    Button { selectDay(day.date) } label: {
                        Text(day.label)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? Color.white.opacity(0.14) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            // Time: hour menu + minute menu
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))

                flatMenu(
                    label: String(format: "%02d", hour),
                    values: Array(0...23),
                    format: { String(format: "%02d", $0) },
                    action: { setHour($0) }
                )

                Text(":")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))

                flatMenu(
                    label: String(format: "%02d", minute),
                    values: stride(from: 0, to: 60, by: 5).map { $0 },
                    format: { String(format: "%02d", $0) },
                    action: { setMinute($0) }
                )
            }
        }
    }

    private func flatMenu(
        label: String,
        values: [Int],
        format: @escaping (Int) -> String,
        action: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(values, id: \.self) { v in
                Button(format(v)) { action(v) }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundColor(.white)
                .frame(width: 36, height: 28)
                .background(Color.white.opacity(0.07))
                .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 36)
    }

    private func selectDay(_ day: Date) {
        var comps = cal.dateComponents([.hour, .minute], from: date)
        comps.year = cal.component(.year, from: day)
        comps.month = cal.component(.month, from: day)
        comps.day = cal.component(.day, from: day)
        if let d = cal.date(from: comps) {
            date = max(d, Date())
        }
    }

    private func setHour(_ h: Int) {
        var comps = cal.dateComponents([.year, .month, .day, .minute], from: date)
        comps.hour = h
        if let d = cal.date(from: comps), d >= Date() {
            date = d
        }
    }

    private func setMinute(_ m: Int) {
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
        comps.minute = m
        if let d = cal.date(from: comps), d >= Date() {
            date = d
        }
    }
}

private let panelBg = Color(white: 0.12)

// MARK: - Add Reminder View

struct AddReminderView: View {
    @State private var text = ""
    @State private var mode: ReminderTimeMode = .atTime
    @State private var selectedTime = Date()
    @State private var intervalValue: Int = 5
    @State private var intervalUnit: TimeUnit = .minutes
    @State private var everyValue: Int = 5
    @State private var everyUnit: TimeUnit = .minutes
    @State private var everyMode: EveryMode = .interval
    @State private var everyHour: Int = 9
    @State private var everyMinute: Int = 0
    @State private var selectedWeekdays: Set<Int> = Set(1...7) // all days by default

    var onSave: (String, Date?, TimeInterval?, [Int]?) -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            VStack(spacing: 14) {
                FlatTextField(placeholder: "Reminder text...", text: $text)
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(8)

                FlatSegmentPicker(selection: $mode)

                Group {
                    switch mode {
                    case .atTime:
                        FlatDateTimePicker(date: $selectedTime)

                    case .inInterval:
                        flatStepper(label: "In", value: $intervalValue, unit: $intervalUnit)

                    case .every:
                        everySection
                    }
                }

                Spacer()

                HStack(spacing: 10) {
                    Button("Cancel") { onCancel() }
                        .buttonStyle(FlatButtonStyle())
                        .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Save") { save() }
                        .buttonStyle(FlatButtonStyle(primary: true))
                        .keyboardShortcut(.defaultAction)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: 380, height: 340)
        .background(panelBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private func flatStepper(
        label: String,
        value: Binding<Int>,
        unit: Binding<TimeUnit>
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 0) {
                Button { if value.wrappedValue > 1 { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)")
                    .font(.system(size: 14).monospacedDigit())
                    .frame(minWidth: 28)

                Button { if value.wrappedValue < 999 { value.wrappedValue += 1 } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .background(Color.white.opacity(0.07))
            .cornerRadius(8)

            HStack(spacing: 2) {
                ForEach(TimeUnit.allCases, id: \.self) { u in
                    Button { unit.wrappedValue = u } label: {
                        Text(u.rawValue)
                            .font(.system(size: 12, weight: unit.wrappedValue == u ? .semibold : .regular))
                            .foregroundColor(unit.wrappedValue == u ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(unit.wrappedValue == u ? Color.white.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }

    // MARK: - Every section

    private var everySection: some View {
        VStack(spacing: 8) {
            // Sub-mode chips: Interval | Schedule
            HStack(spacing: 4) {
                ForEach(EveryMode.allCases, id: \.self) { m in
                    Button { everyMode = m } label: {
                        Text(m.rawValue)
                            .font(.system(size: 11, weight: everyMode == m ? .semibold : .regular))
                            .foregroundColor(everyMode == m ? .white : .white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(everyMode == m ? Color.white.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            switch everyMode {
            case .interval:
                flatStepper(label: "Every", value: $everyValue, unit: $everyUnit)

            case .schedule:
                weekdayChips
                flatTimePicker(hour: $everyHour, minute: $everyMinute, prefix: "at")
            }
        }
    }

    private var weekdayChips: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols // S M T W T F S
        // Reorder: Mon first → indices 1,2,3,4,5,6,0
        let ordered = (1...6).map { $0 } + [0]

        return HStack(spacing: 4) {
            ForEach(ordered, id: \.self) { idx in
                let weekday = idx + 1 // Calendar weekday: 1=Sun...7=Sat
                let selected = selectedWeekdays.contains(weekday)
                Button {
                    if selected {
                        // Don't allow deselecting all
                        if selectedWeekdays.count > 1 {
                            selectedWeekdays.remove(weekday)
                        }
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                } label: {
                    Text(symbols[idx])
                        .font(.system(size: 11, weight: selected ? .bold : .regular))
                        .foregroundColor(selected ? .white : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(selected ? Color.white.opacity(0.14) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func flatTimePicker(hour: Binding<Int>, minute: Binding<Int>, prefix: String) -> some View {
        HStack(spacing: 6) {
            Text(prefix)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))

            flatMenu(
                label: String(format: "%02d", hour.wrappedValue),
                values: Array(0...23),
                format: { String(format: "%02d", $0) },
                action: { hour.wrappedValue = $0 }
            )

            Text(":")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.3))

            flatMenu(
                label: String(format: "%02d", minute.wrappedValue),
                values: stride(from: 0, to: 60, by: 5).map { $0 },
                format: { String(format: "%02d", $0) },
                action: { minute.wrappedValue = $0 }
            )
        }
    }

    private func flatMenu(
        label: String,
        values: [Int],
        format: @escaping (Int) -> String,
        action: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(values, id: \.self) { v in
                Button(format(v)) { action(v) }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundColor(.white)
                .frame(width: 36, height: 28)
                .background(Color.white.opacity(0.07))
                .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 36)
    }

    // MARK: - Save

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .atTime:
            onSave(trimmed, selectedTime, nil, nil)

        case .inInterval:
            let seconds = TimeInterval(intervalValue) * intervalUnit.seconds
            let fire = Date().addingTimeInterval(seconds)
            onSave(trimmed, fire, nil, nil)

        case .every:
            switch everyMode {
            case .interval:
                let seconds = TimeInterval(everyValue) * everyUnit.seconds
                let fire = Date().addingTimeInterval(seconds)
                onSave(trimmed, fire, seconds, nil)

            case .schedule:
                let weekdays = Array(selectedWeekdays).sorted()
                let fire = ReminderStore.nextWeekdayOccurrence(
                    after: Date(),
                    weekdays: weekdays,
                    hour: everyHour,
                    minute: everyMinute
                )
                onSave(trimmed, fire, nil, weekdays)
            }
        }
    }
}

// MARK: - Reminders List View

struct RemindersListView: View {
    let reminders: [Reminder]
    var onDelete: (UUID) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            VStack(spacing: 12) {
                HStack {
                    Text("Reminders")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(reminders.count)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(6)
                }

                if reminders.isEmpty {
                    Spacer()
                    Text("No reminders")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(reminders) { r in
                                reminderRow(r)
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Close") { onClose() }
                        .buttonStyle(FlatButtonStyle())
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: 320, height: 300)
        .background(panelBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private func reminderRow(_ r: Reminder) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.text)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if r.isRecurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                        Text(formatRecurring(r))
                            .font(.system(size: 11))
                    } else if let date = r.fireDate {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(date, style: .relative)
                            .font(.system(size: 11))
                    }
                }
                .foregroundColor(.white.opacity(0.35))
            }

            Spacer()

            Button {
                onDelete(r.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }

    private func formatRecurring(_ r: Reminder) -> String {
        if let weekdays = r.recurringWeekdays {
            let syms = Calendar.current.veryShortWeekdaySymbols
            let allDays = Set(1...7)
            if Set(weekdays) == allDays {
                if let d = r.fireDate {
                    let h = Calendar.current.component(.hour, from: d)
                    let m = Calendar.current.component(.minute, from: d)
                    return String(format: "daily %02d:%02d", h, m)
                }
                return "daily"
            }
            let names = weekdays.sorted().map { syms[$0 - 1] }.joined(separator: " ")
            if let d = r.fireDate {
                let h = Calendar.current.component(.hour, from: d)
                let m = Calendar.current.component(.minute, from: d)
                return String(format: "%@ %02d:%02d", names, h, m)
            }
            return names
        }
        if let interval = r.recurringInterval {
            if interval >= 3600 {
                let h = Int(interval / 3600)
                return "every \(h)h"
            }
            let m = Int(interval / 60)
            return "every \(m)m"
        }
        return ""
    }
}

// MARK: - Shared drag handle

private var dragHandle: some View {
    RoundedRectangle(cornerRadius: 2)
        .fill(Color.white.opacity(0.2))
        .frame(width: 36, height: 4)
        .padding(.top, 10)
        .padding(.bottom, 14)
}

// MARK: - Borderless panel

private class BorderlessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private var initialMouseLocation: NSPoint?

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let initial = initialMouseLocation else { return }
        let current = event.locationInWindow
        let dx = current.x - initial.x
        let dy = current.y - initial.y
        var origin = frame.origin
        origin.x += dx
        origin.y += dy
        setFrameOrigin(origin)
    }
}

@MainActor
private func makeFlatPanel(width: CGFloat, height: CGFloat) -> BorderlessPanel {
    let panel = BorderlessPanel(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = false
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    return panel
}

// MARK: - Panel presenters

@MainActor
func showAddReminderPanel(onSave: @escaping (String, Date?, TimeInterval?, [Int]?) -> Void) {
    let panel = makeFlatPanel(width: 380, height: 340)

    let hostingView = NSHostingView(
        rootView: AddReminderView(
            onSave: { text, fireDate, recurringInterval, weekdays in
                onSave(text, fireDate, recurringInterval, weekdays)
                panel.close()
            },
            onCancel: {
                panel.close()
            }
        )
    )

    panel.contentView = hostingView
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

@MainActor
func showRemindersListPanel(store: ReminderStore) {
    let panel = makeFlatPanel(width: 320, height: 300)

    final class State: ObservableObject {
        @Published var reminders: [Reminder]
        let store: ReminderStore

        init(store: ReminderStore) {
            self.store = store
            self.reminders = store.allPending
        }

        func delete(id: UUID) {
            store.remove(id: id)
            reminders = store.allPending
        }
    }

    let state = State(store: store)

    struct Wrapper: View {
        @ObservedObject var state: State
        var onClose: () -> Void

        var body: some View {
            RemindersListView(
                reminders: state.reminders,
                onDelete: { state.delete(id: $0) },
                onClose: onClose
            )
        }
    }

    let hostingView = NSHostingView(
        rootView: Wrapper(state: state, onClose: { panel.close() })
    )

    panel.contentView = hostingView
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
