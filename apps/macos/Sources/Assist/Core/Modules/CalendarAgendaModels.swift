import Foundation

struct AgendaEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
}

struct AgendaReminder: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let dueDate: Date?
}

struct AgendaDay: Identifiable, Equatable, Sendable {
    /// The start of the day.
    let day: Date
    let events: [AgendaEvent]

    var id: Date { day }
}

enum AgendaGrouping {
    /// One entry per day from `start`, with every event that overlaps the
    /// day, all-day events first. Days without events are left out.
    static func days(
        for events: [AgendaEvent],
        from start: Date,
        dayCount: Int,
        calendar: Calendar
    ) -> [AgendaDay] {
        let firstDay = calendar.startOfDay(for: start)
        return (0..<max(dayCount, 0)).compactMap { offset -> AgendaDay? in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

            let dayEvents = events
                .filter { event in
                    // Zero-length events still belong to the day they start on.
                    event.start < dayEnd && (event.end > dayStart || event.start >= dayStart)
                }
                .sorted { lhs, rhs in
                    if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                    if lhs.start != rhs.start { return lhs.start < rhs.start }
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
            return dayEvents.isEmpty ? nil : AgendaDay(day: dayStart, events: dayEvents)
        }
    }

    /// "Today", "Tomorrow", or a short weekday and date such as "Fri 26".
    static func title(for day: Date, relativeTo now: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return "Today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEd")
        return formatter.string(from: day)
    }

    /// Reminders due soonest first; ones without a due date follow, by title.
    static func sortedReminders(_ reminders: [AgendaReminder]) -> [AgendaReminder] {
        reminders.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }
}
