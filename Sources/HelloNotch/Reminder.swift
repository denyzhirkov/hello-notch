import Foundation
import os

struct Reminder: Codable, Identifiable {
    let id: UUID
    var text: String
    var done: Bool
    var fireDate: Date?
    var recurringInterval: TimeInterval?
    var recurringWeekdays: [Int]? // 1=Sun,2=Mon...7=Sat; nil = not schedule-based
    var snoozedUntil: Date?

    init(
        id: UUID = UUID(),
        text: String,
        done: Bool = false,
        fireDate: Date? = nil,
        recurringInterval: TimeInterval? = nil,
        recurringWeekdays: [Int]? = nil,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.done = done
        self.fireDate = fireDate
        self.recurringInterval = recurringInterval
        self.recurringWeekdays = recurringWeekdays
        self.snoozedUntil = snoozedUntil
    }

    var isRecurring: Bool {
        recurringInterval != nil || recurringWeekdays != nil
    }

    /// Effective date at which the reminder should become due, considering snooze.
    var effectiveFireDate: Date? {
        switch (fireDate, snoozedUntil) {
        case let (f?, s?): return max(f, s)
        case let (f?, nil): return f
        case let (nil, s?): return s
        case (nil, nil): return nil
        }
    }
}

@MainActor
final class ReminderStore {

    private var reminders: [Reminder] = []
    private let fileURL: URL
    private let logger = Logger(subsystem: "com.hellonotch.app", category: "ReminderStore")

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first.map { $0.appendingPathComponent("HelloNotch") }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("HelloNotch")

        try? FileManager.default.createDirectory(
            at: appSupport, withIntermediateDirectories: true
        )

        fileURL = appSupport.appendingPathComponent("reminders.json")
        load()
    }

    // MARK: - Public API

    /// Minimum allowed recurring interval. Sub-5-minute repeats are more spam than utility
    /// and also guard the app against accidental tight-loops from hand-edited JSON.
    static let minRecurringInterval: TimeInterval = 300

    /// Adds a reminder, normalizing invalid recurring inputs instead of silently breaking.
    /// - Empty weekdays → dropped to nil (treated as non-schedule).
    /// - `recurringInterval < minRecurringInterval` → dropped to nil.
    /// - Recurring without `fireDate` → fireDate computed so markDone has an anchor.
    func add(
        text: String,
        fireDate: Date? = nil,
        recurringInterval: TimeInterval? = nil,
        recurringWeekdays: [Int]? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.warning("add() called with empty text — ignored")
            return
        }

        let normalizedInterval: TimeInterval? = {
            guard let i = recurringInterval, i >= Self.minRecurringInterval else { return nil }
            return i
        }()

        let normalizedWeekdays: [Int]? = {
            guard let w = recurringWeekdays, !w.isEmpty else { return nil }
            return w
        }()

        let isRecurring = normalizedInterval != nil || normalizedWeekdays != nil

        let anchoredFireDate: Date? = {
            if let f = fireDate { return f }
            guard isRecurring else { return nil }
            let now = Date()
            if let weekdays = normalizedWeekdays {
                let cal = Calendar.current
                let h = cal.component(.hour, from: now)
                let m = cal.component(.minute, from: now)
                return Self.nextWeekdayOccurrence(after: now, weekdays: weekdays, hour: h, minute: m)
                    ?? now
            }
            if let interval = normalizedInterval {
                return now.addingTimeInterval(interval)
            }
            return nil
        }()

        reminders.append(
            Reminder(
                text: trimmed,
                fireDate: anchoredFireDate,
                recurringInterval: normalizedInterval,
                recurringWeekdays: normalizedWeekdays
            )
        )
        save()
    }

    func markDone(id: UUID) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }

        // Clear any active snooze: completing supersedes it.
        reminders[idx].snoozedUntil = nil

        let now = Date()

        if let weekdays = reminders[idx].recurringWeekdays, !weekdays.isEmpty {
            let cal = Calendar.current
            // Anchor hour/minute to the ORIGINAL fireDate when available.
            // Legacy records without fireDate fall back to current time, which is
            // imperfect but keeps the reminder alive instead of killing it.
            let anchor = reminders[idx].fireDate ?? now
            let h = cal.component(.hour, from: anchor)
            let m = cal.component(.minute, from: anchor)
            reminders[idx].fireDate = Self.nextWeekdayOccurrence(
                after: now, weekdays: weekdays, hour: h, minute: m
            ) ?? now.addingTimeInterval(86400)
        } else if let interval = reminders[idx].recurringInterval, interval > 0 {
            var nextDate = reminders[idx].fireDate ?? now
            if nextDate <= now {
                nextDate = nextDate.addingTimeInterval(interval)
                while nextDate <= now {
                    nextDate = nextDate.addingTimeInterval(interval)
                }
            }
            reminders[idx].fireDate = nextDate
        } else {
            // One-shot reminder: remove entirely rather than leaving a tombstone
            // in the array. Prevents JSON file from growing forever.
            reminders.remove(at: idx)
            save()
            return
        }
        save()
    }

    /// Defers a reminder without mutating its canonical schedule.
    /// For recurring reminders this preserves the original hour/minute so
    /// repeated snoozes don't drift the schedule.
    func snooze(id: UUID, seconds: TimeInterval = Config.snoozeSeconds) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].snoozedUntil = Date().addingTimeInterval(seconds)
        save()
    }

    func remove(id: UUID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    func dueReminders() -> [Reminder] {
        let now = Date()
        return reminders.filter { r in
            guard !r.done else { return false }
            guard let eff = r.effectiveFireDate else { return false }
            return eff <= now
        }
    }

    var allPending: [Reminder] {
        reminders.filter { !$0.done }
    }

    // MARK: - Helpers

    /// Next date matching one of the given weekdays at the given hour/minute, strictly after `date`.
    /// Returns nil for empty `weekdays` or if no candidate is found within the 7-day window
    /// (should not happen for non-empty weekdays, but callers must handle nil explicitly).
    static func nextWeekdayOccurrence(
        after date: Date,
        weekdays: [Int],
        hour: Int,
        minute: Int
    ) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let cal = Calendar.current
        for dayOffset in 0...7 {
            guard let candidate = cal.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let wd = cal.component(.weekday, from: candidate)
            guard weekdays.contains(wd) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: candidate)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard let d = cal.date(from: comps), d > date else { continue }
            return d
        }
        return nil
    }

    // MARK: - Persistence

    private func load() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // Missing file on first launch is expected.
            if (error as NSError).code != NSFileReadNoSuchFileError {
                logger.error("Failed to read reminders.json: \(error.localizedDescription)")
            }
            return
        }

        do {
            reminders = try JSONDecoder().decode([Reminder].self, from: data)
            return
        } catch {
            logger.warning("reminders.json decode failed: \(error.localizedDescription). Attempting per-item recovery.")
        }

        if let recovered = recoverPartial(from: data), !recovered.isEmpty {
            logger.notice("Recovered \(recovered.count) reminder(s) from partially-corrupted file. Rewriting clean.")
            reminders = recovered
            save()
            return
        }

        backupCorruptedFile()
        reminders = []
    }

    /// Per-element decode. Survives single malformed entries by keeping the rest.
    /// Relies on default JSONEncoder/Decoder date strategy (`.deferredToDate`) matching
    /// what JSONSerialization produces when re-encoding elements.
    private func recoverPartial(from data: Data) -> [Reminder]? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return nil
        }
        let decoder = JSONDecoder()
        var recovered: [Reminder] = []
        for element in array {
            guard
                let elementData = try? JSONSerialization.data(withJSONObject: element),
                let reminder = try? decoder.decode(Reminder.self, from: elementData)
            else { continue }
            recovered.append(reminder)
        }
        return recovered
    }

    private func backupCorruptedFile() {
        let ts = Int(Date().timeIntervalSince1970)
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("reminders.corrupted-\(ts).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: backupURL)
            logger.error("reminders.json unrecoverable. Backed up to \(backupURL.lastPathComponent).")
        } catch {
            logger.error("Failed to back up corrupted reminders.json: \(error.localizedDescription)")
        }
    }

    private func save() {
        let data: Data
        do {
            data = try JSONEncoder().encode(reminders)
        } catch {
            logger.error("Failed to encode reminders: \(error.localizedDescription)")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to write reminders.json: \(error.localizedDescription)")
        }
    }
}
