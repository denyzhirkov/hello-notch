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
                        .contentShape(Rectangle())
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
        let shortWeekday = ["Su", "Mn", "Tu", "Wd", "Th", "Fr", "Sa"]
        return (0..<7).compactMap { offset -> (String, Date)? in
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let label: String
            switch offset {
            case 0: label = "Tdy"
            case 1: label = "Tmr"
            default:
                let wd = shortWeekday[cal.component(.weekday, from: d) - 1]
                let day = cal.component(.day, from: d)
                label = "\(wd) \(day)"
            }
            return (label, d)
        }
    }

    private var hour: Int { cal.component(.hour, from: date) }
    private var minute: Int { cal.component(.minute, from: date) }

    private var hourBinding: Binding<Int> {
        Binding(get: { hour }, set: { setHour($0) })
    }
    private var minuteBinding: Binding<Int> {
        Binding(get: { minute }, set: { setMinute($0) })
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
                            .contentShape(Rectangle())
                            .background(isSelected ? Color.white.opacity(0.14) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                FlatTimePicker12h(hour24: hourBinding, minute: minuteBinding)
            }
        }
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

// MARK: - Flat Stepper Row

struct FlatStepperRow: View {
    let label: String
    @Binding var value: Int
    @Binding var unit: TimeUnit
    @State private var showDecades = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 0) {
                Button { if value > 1 { value -= 1 } } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text("\(value)")
                    .font(.system(size: 14).monospacedDigit())
                    .frame(minWidth: 28)
                    .contentShape(Rectangle())
                    .onTapGesture { showDecades.toggle() }
                    .popover(isPresented: $showDecades, arrowEdge: .bottom) {
                        decadesGrid
                    }

                Button { if value < 999 { value += 1 } } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Color.white.opacity(0.07))
            .cornerRadius(8)

            HStack(spacing: 2) {
                ForEach(TimeUnit.allCases, id: \.self) { u in
                    Button { unit = u } label: {
                        Text(u.rawValue)
                            .font(.system(size: 12, weight: unit == u ? .semibold : .regular))
                            .foregroundColor(unit == u ? .white : .white.opacity(0.4))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .background(unit == u ? Color.white.opacity(0.12) : Color.clear)
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

    private var decadesGrid: some View {
        let decades = Array(stride(from: 10, through: 90, by: 10))
        return HStack(spacing: 4) {
            ForEach(decades, id: \.self) { d in
                Button {
                    value = d
                    showDecades = false
                } label: {
                    Text("\(d)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 30, height: 26)
                        .background(Color.white.opacity(value == d ? 0.18 : 0.07))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(white: 0.14))
        .preferredColorScheme(.dark)
    }
}

// MARK: - 12h time picker

struct FlatTimePicker12h: View {
    @Binding var hour24: Int  // 0–23
    @Binding var minute: Int
    var prefix: String = ""

    private var hour12: Int {
        let h = hour24 % 12
        return h == 0 ? 12 : h
    }
    private var isAM: Bool { hour24 < 12 }

    var body: some View {
        HStack(spacing: 6) {
            if !prefix.isEmpty {
                Text(prefix)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            flatMenu(
                label: "\(hour12)",
                values: Array(1...12),
                format: { "\($0)" },
                action: { h in
                    hour24 = isAM ? (h == 12 ? 0 : h) : (h == 12 ? 12 : h + 12)
                }
            )

            Text(":")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.3))

            flatMenu(
                label: String(format: "%02d", minute),
                values: minuteValues,
                format: { String(format: "%02d", $0) },
                action: { minute = $0 }
            )

            Button { hour24 = (hour24 + 12) % 24 } label: {
                Text(isAM ? "AM" : "PM")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 28)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Shared flat menu

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

private let minuteValues = Array(stride(from: 0, to: 60, by: 5))

// MARK: - Frosted-glass background

/// NSVisualEffectView wrapper. `.hudWindow` + `.behindWindow` gives true frosted glass
/// that picks up the desktop beneath the panel (requires the hosting NSPanel to be
/// non-opaque with a clear backgroundColor — `makeFlatPanel` already does that).
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

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

    /// Content-only view (no chrome). Host provides background, frame, header.
    var body: some View {
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

            HStack {
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(FlatButtonStyle(primary: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func flatStepper(
        label: String,
        value: Binding<Int>,
        unit: Binding<TimeUnit>
    ) -> some View {
        FlatStepperRow(label: label, value: value, unit: unit)
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
                            .contentShape(Rectangle())
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
                    .help("Minimum 5 min for recurring — shorter values are rounded up")

            case .schedule:
                weekdayChips
                flatTimePicker(hour: $everyHour, minute: $everyMinute, prefix: "at")
            }
        }
    }

    private var weekdayChips: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols // S M T W T F S
        // Reorder: Mon first → indices 1,2,3,4,5,6,0
        let ordered = Array(1...6) + [0]

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
                        .contentShape(Rectangle())
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
        FlatTimePicker12h(hour24: hour, minute: minute, prefix: prefix)
    }

    // MARK: - Save

    @MainActor private func save() {
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
                let raw = TimeInterval(everyValue) * everyUnit.seconds
                let seconds = max(raw, ReminderStore.minRecurringInterval)
                let fire = Date().addingTimeInterval(seconds)
                onSave(trimmed, fire, seconds, nil)

            case .schedule:
                let weekdays = Array(selectedWeekdays).sorted()
                guard !weekdays.isEmpty else { return }
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

    /// Content-only view (no chrome, no title — host renders header with count).
    var body: some View {
        Group {
            if reminders.isEmpty {
                VStack {
                    Spacer()
                    Text("No reminders")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(reminders) { r in
                            reminderRow(r)
                        }
                    }
                }
            }
        }
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

var dragHandle: some View {
    RoundedRectangle(cornerRadius: 2)
        .fill(Color.white.opacity(0.2))
        .frame(width: 36, height: 4)
        .padding(.top, 10)
        .padding(.bottom, 14)
}

// MARK: - Borderless panel

class BorderlessPanel: NSPanel {
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
func makeFlatPanel(width: CGFloat, height: CGFloat) -> BorderlessPanel {
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

// MARK: - Combined Reminders Window

enum RemindersWindowMode {
    case list
    case add
}

@MainActor
final class RemindersWindowState: ObservableObject {
    @Published var mode: RemindersWindowMode
    @Published var reminders: [Reminder]
    let store: ReminderStore

    init(store: ReminderStore, mode: RemindersWindowMode) {
        self.store = store
        self.mode = mode
        self.reminders = store.allPending
    }

    func refresh() {
        reminders = store.allPending
    }

    func delete(id: UUID) {
        store.remove(id: id)
        refresh()
    }

    func addReminder(text: String, fireDate: Date?, interval: TimeInterval?, weekdays: [Int]?) {
        store.add(
            text: text,
            fireDate: fireDate,
            recurringInterval: interval,
            recurringWeekdays: weekdays
        )
        refresh()
        withAnimation(.easeInOut(duration: 0.22)) {
            mode = .list
        }
    }
}

struct RemindersWindowView: View {
    @ObservedObject var state: RemindersWindowState
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            content
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .frame(width: 380, height: 380)
        .background(VisualEffectBlur())
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .onExitCommand {
            switch state.mode {
            case .add:
                withAnimation(.easeInOut(duration: 0.22)) { state.mode = .list }
            case .list:
                onClose()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if state.mode == .add {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { state.mode = .list }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }

            Text(state.mode == .list ? "Reminders" : "New Reminder")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Spacer()


            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("w", modifiers: .command)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state.mode {
        case .list:
            VStack(spacing: 8) {
                RemindersListView(
                    reminders: state.reminders,
                    onDelete: { state.delete(id: $0) }
                )

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { state.mode = .add }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        case .add:
            AddReminderView(
                onSave: { text, fireDate, interval, weekdays in
                    state.addReminder(text: text, fireDate: fireDate, interval: interval, weekdays: weekdays)
                }
            )
        }
    }
}

@MainActor
func showRemindersPanel(store: ReminderStore, initialMode: RemindersWindowMode = .list) {
    let panel = makeFlatPanel(width: 380, height: 380)
    let state = RemindersWindowState(store: store, mode: initialMode)

    struct Host: View {
        @ObservedObject var state: RemindersWindowState
        var onClose: () -> Void
        var body: some View {
            RemindersWindowView(state: state, onClose: onClose)
        }
    }

    panel.contentView = NSHostingView(
        rootView: Host(state: state, onClose: { panel.close() })
    )
    panel.center()
    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
