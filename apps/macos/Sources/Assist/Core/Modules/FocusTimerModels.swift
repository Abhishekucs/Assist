import Foundation

enum TimerMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case pomodoro
    case countdown
    case stopwatch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pomodoro: "Focus"
        case .countdown: "Timer"
        case .stopwatch: "Stopwatch"
        }
    }
}

enum PomodoroPhase: String, Codable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

/// The classic Pomodoro routine: 25-minute focus sessions, 5-minute breaks,
/// and a 15-minute break after every fourth session.
struct PomodoroPlan: Equatable, Sendable {
    var focus: TimeInterval = 25 * 60
    var shortBreak: TimeInterval = 5 * 60
    var longBreak: TimeInterval = 15 * 60
    var sessionsBeforeLongBreak = 4

    func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }

    /// The phase that follows a finished one. `completedFocusSessions`
    /// already counts a focus session that just finished.
    func phase(after phase: PomodoroPhase, completedFocusSessions: Int) -> PomodoroPhase {
        switch phase {
        case .focus:
            completedFocusSessions > 0 && completedFocusSessions % sessionsBeforeLongBreak == 0
                ? .longBreak
                : .shortBreak
        case .shortBreak, .longBreak:
            .focus
        }
    }
}

/// A clock measured against wall-clock dates rather than counted ticks, so a
/// busy main thread or a sleeping Mac never makes it drift.
struct TimerClock: Equatable, Sendable {
    private(set) var accumulated: TimeInterval = 0
    private(set) var startedAt: Date?

    var isRunning: Bool {
        startedAt != nil
    }

    var hasStarted: Bool {
        isRunning || accumulated > 0
    }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(now.timeIntervalSince($0), 0) } ?? 0)
    }

    mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    mutating func pause(at now: Date) {
        guard let startedAt else { return }
        accumulated += max(now.timeIntervalSince(startedAt), 0)
        self.startedAt = nil
    }

    mutating func reset() {
        accumulated = 0
        startedAt = nil
    }
}

enum TimerFormatting {
    /// "4:05", "24:59", or "1:02:03"; partial seconds round up for countdowns
    /// so a timer shows "0:01" until it actually finishes.
    static func clock(_ interval: TimeInterval, roundingUp: Bool = false) -> String {
        let clamped = max(interval, 0)
        let seconds = Int(roundingUp ? clamped.rounded(.up) : clamped.rounded(.down))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }

    /// "45 min", "1 hr", "1 hr 30 min".
    static func minutes(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((max(interval, 0) / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(minutes) min"
        }
    }
}
