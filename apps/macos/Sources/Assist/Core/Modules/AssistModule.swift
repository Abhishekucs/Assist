import Foundation

/// A section of the notch island. Clipboard is the original capture shelf and
/// always stays available; every other module can be turned on or off in
/// the Assist app's module sidebar.
enum AssistModule: String, CaseIterable, Identifiable, Codable, Sendable {
    case clipboard
    case shelf
    case notes
    case timers
    case calendar
    case media
    case stats
    case screenTime
    case converter
    case revenue
    case aiUsage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .shelf: "Shelf"
        case .notes: "Notes"
        case .timers: "Timers"
        case .calendar: "Calendar"
        case .media: "Media"
        case .stats: "System"
        case .screenTime: "Screen Time"
        case .converter: "Convert"
        case .revenue: "Revenue"
        case .aiUsage: "AI Usage"
        }
    }

    /// The one-line description shown beside the module's toggle in Assist.
    var detail: String {
        switch self {
        case .clipboard:
            "Screenshots and copied text. Always on."
        case .shelf:
            "Drop files on the notch to keep them close, then drag them out anywhere."
        case .notes:
            "A scratchpad that is always one hover away. Pin the notch while you type."
        case .timers:
            "Pomodoro focus sessions, countdowns, a stopwatch, and hydration reminders."
        case .calendar:
            "A seven-day agenda and reminders you can tick off in place."
        case .media:
            "Now playing from Music or Spotify, with play, pause, and skip."
        case .stats:
            "CPU, memory, disk, network, and battery at a glance."
        case .screenTime:
            "Where today went, app by app. Tracked only on this Mac."
        case .converter:
            "Drop images to convert and shrink them to JPEG, PNG, HEIC, or PDF."
        case .revenue:
            "Today, 7-day, and 30-day sales from Stripe, Polar, or Dodo Payments, using read-only keys you add below."
        case .aiUsage:
            "Daily Claude Code and Codex token activity, read from their logs on this Mac."
        }
    }

    /// Clipboard holds the existing capture history, so it cannot be turned off.
    var isRequired: Bool {
        self == .clipboard
    }

    /// Modules that receive files dropped on the island.
    var acceptsFileDrops: Bool {
        self == .shelf || self == .converter
    }

    static let defaultEnabled: [AssistModule] = [.clipboard, .shelf, .notes, .timers, .stats]
}
