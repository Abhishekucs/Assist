import Foundation

struct ScreenTimeEntry: Identifiable, Equatable, Sendable {
    let bundleIdentifier: String
    let name: String
    let duration: TimeInterval

    var id: String { bundleIdentifier }
}

/// Seconds spent in each app, per local day. Only app identifiers, names, and
/// durations are kept; nothing about what happened inside an app.
struct ScreenTimeLedger: Codable, Equatable, Sendable {
    static let retainedDayCount = 7

    /// Seconds per bundle identifier, keyed by day ("2026-09-23").
    private(set) var days: [String: [String: TimeInterval]] = [:]
    /// The most recent display name for each bundle identifier.
    private(set) var names: [String: String] = [:]

    /// Adds the time between two dates to an app, splitting it at midnight so
    /// each day gets its own share.
    mutating func record(
        from start: Date,
        to end: Date,
        bundleIdentifier: String,
        name: String,
        calendar: Calendar
    ) {
        guard end > start else { return }
        names[bundleIdentifier] = name

        var segmentStart = start
        while segmentStart < end {
            let dayStart = calendar.startOfDay(for: segmentStart)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? end
            let segmentEnd = min(end, nextDay)
            let key = Self.dayKey(for: segmentStart, calendar: calendar)
            days[key, default: [:]][bundleIdentifier, default: 0] += segmentEnd.timeIntervalSince(segmentStart)
            segmentStart = segmentEnd
        }
    }

    /// Apps used on a day, most used first.
    func entries(on day: Date, calendar: Calendar) -> [ScreenTimeEntry] {
        let usage = days[Self.dayKey(for: day, calendar: calendar)] ?? [:]
        return usage
            .map { ScreenTimeEntry(bundleIdentifier: $0.key, name: names[$0.key] ?? $0.key, duration: $0.value) }
            .sorted { lhs, rhs in
                lhs.duration == rhs.duration
                    ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    : lhs.duration > rhs.duration
            }
    }

    func total(on day: Date, calendar: Calendar) -> TimeInterval {
        (days[Self.dayKey(for: day, calendar: calendar)] ?? [:]).values.reduce(0, +)
    }

    /// Keeps the most recent days up to `retainedDayCount`, and the names
    /// those days still use.
    mutating func prune() {
        let keptDays = days.keys.sorted().suffix(Self.retainedDayCount)
        days = days.filter { keptDays.contains($0.key) }
        let usedIdentifiers = Set(days.values.flatMap(\.keys))
        names = names.filter { usedIdentifiers.contains($0.key) }
    }

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
