import Foundation

struct Reminder: Codable, Identifiable {
    let id: UUID
    var text: String
    var done: Bool
    var fireDate: Date?
    var recurringInterval: TimeInterval?
    var recurringWeekdays: [Int]? // 1=Sun,2=Mon...7=Sat; nil = not schedule-based

    init(
        id: UUID = UUID(),
        text: String,
        done: Bool = false,
        fireDate: Date? = nil,
        recurringInterval: TimeInterval? = nil,
        recurringWeekdays: [Int]? = nil
    ) {
        self.id = id
        self.text = text
        self.done = done
        self.fireDate = fireDate
        self.recurringInterval = recurringInterval
        self.recurringWeekdays = recurringWeekdays
    }

    /// Whether this is any kind of recurring reminder.
    var isRecurring: Bool {
        recurringInterval != nil || recurringWeekdays != nil
    }
}

final class ReminderStore {

    private var reminders: [Reminder] = []
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("HelloNotch")

        try? FileManager.default.createDirectory(
            at: appSupport, withIntermediateDirectories: true
        )

        fileURL = appSupport.appendingPathComponent("reminders.json")
        load()
    }

    // MARK: - Public API

    func add(
        text: String,
        fireDate: Date? = nil,
        recurringInterval: TimeInterval? = nil,
        recurringWeekdays: [Int]? = nil
    ) {
        reminders.append(
            Reminder(
                text: text,
                fireDate: fireDate,
                recurringInterval: recurringInterval,
                recurringWeekdays: recurringWeekdays
            )
        )
        save()
    }

    func markDone(id: UUID) {
        if let idx = reminders.firstIndex(where: { $0.id == id }) {
            if let weekdays = reminders[idx].recurringWeekdays,
               let oldDate = reminders[idx].fireDate {
                // Schedule-based: find next matching weekday+time
                reminders[idx].fireDate = Self.nextWeekdayOccurrence(
                    after: Date(),
                    weekdays: weekdays,
                    hour: Calendar.current.component(.hour, from: oldDate),
                    minute: Calendar.current.component(.minute, from: oldDate)
                )
            } else if let interval = reminders[idx].recurringInterval,
                      let oldDate = reminders[idx].fireDate {
                var nextDate = oldDate + interval
                while nextDate <= Date() {
                    nextDate += interval
                }
                reminders[idx].fireDate = nextDate
            } else {
                reminders[idx].done = true
            }
            save()
        }
    }

    func snooze(id: UUID, seconds: TimeInterval = 60) {
        if let idx = reminders.firstIndex(where: { $0.id == id }) {
            reminders[idx].fireDate = Date().addingTimeInterval(seconds)
            save()
        }
    }

    func remove(id: UUID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    func dueReminders() -> [Reminder] {
        let now = Date()
        return reminders.filter { !$0.done && $0.fireDate != nil && $0.fireDate! <= now }
    }

    func next() -> Reminder? {
        reminders.first { !$0.done }
    }

    var allPending: [Reminder] {
        reminders.filter { !$0.done }
    }

    var pendingCount: Int {
        allPending.count
    }

    // MARK: - Helpers

    /// Find the next Date matching any of the given weekdays at the specified time.
    static func nextWeekdayOccurrence(
        after date: Date,
        weekdays: [Int],
        hour: Int,
        minute: Int
    ) -> Date {
        let cal = Calendar.current
        // Try each of the next 8 days, pick the earliest match
        var best: Date?
        for dayOffset in 0...7 {
            guard let candidate = cal.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let wd = cal.component(.weekday, from: candidate)
            guard weekdays.contains(wd) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: candidate)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard let d = cal.date(from: comps), d > date else { continue }
            best = d
            break
        }
        return best ?? date.addingTimeInterval(86400)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        reminders = (try? JSONDecoder().decode([Reminder].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
