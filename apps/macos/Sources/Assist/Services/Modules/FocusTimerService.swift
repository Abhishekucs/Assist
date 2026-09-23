import AppKit

/// Pomodoro, countdown, and stopwatch timers, plus the hydration reminder.
/// Time is measured against the wall clock; the one-second ticker only runs
/// while a timer is running, to refresh what is on screen.
@MainActor
final class FocusTimerService: ObservableObject {
    static let countdownPresets: [TimeInterval] = [5 * 60, 10 * 60, 15 * 60, 30 * 60, 60 * 60]
    static let countdownRange: ClosedRange<TimeInterval> = 60...(3 * 60 * 60)
    static let hydrationIntervals: [TimeInterval] = [30 * 60, 45 * 60, 60 * 60, 90 * 60]

    @Published private(set) var mode: TimerMode
    @Published private(set) var clock = TimerClock()
    @Published private(set) var phase: PomodoroPhase = .focus
    @Published private(set) var completedFocusSessions = 0
    @Published private(set) var countdownDuration: TimeInterval
    /// Refreshed every second while a timer runs, so views re-render.
    @Published private(set) var now = Date()
    @Published private(set) var isHydrationEnabled: Bool
    @Published private(set) var hydrationInterval: TimeInterval
    @Published private(set) var nextHydrationAt: Date?

    let plan = PomodoroPlan()
    /// Shows a short message on the island, such as "Break time".
    var onAlert: ((_ badge: String, _ detail: String) -> Void)?

    private let defaults: UserDefaults
    private var ticker: Timer?
    private var hydrationTimer: Timer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: Keys.mode).flatMap(TimerMode.init(rawValue:)) ?? .pomodoro
        let storedCountdown = defaults.double(forKey: Keys.countdownDuration)
        countdownDuration = storedCountdown > 0
            ? min(max(storedCountdown, Self.countdownRange.lowerBound), Self.countdownRange.upperBound)
            : 10 * 60
        isHydrationEnabled = defaults.bool(forKey: Keys.hydrationEnabled)
        let storedInterval = defaults.double(forKey: Keys.hydrationInterval)
        hydrationInterval = Self.hydrationIntervals.contains(storedInterval) ? storedInterval : 45 * 60
    }

    // MARK: - Timers

    var isRunning: Bool {
        clock.isRunning
    }

    /// The length of the current run; the stopwatch has none.
    var duration: TimeInterval? {
        switch mode {
        case .pomodoro: plan.duration(of: phase)
        case .countdown: countdownDuration
        case .stopwatch: nil
        }
    }

    /// The time the clock shows: remaining for timers, elapsed for the stopwatch.
    var displayTime: String {
        let elapsed = clock.elapsed(at: now)
        guard let duration else {
            return TimerFormatting.clock(elapsed)
        }
        return TimerFormatting.clock(duration - elapsed, roundingUp: true)
    }

    /// How far the current run has gone, from 0 to 1; nil for the stopwatch.
    var progress: Double? {
        guard let duration, duration > 0 else { return nil }
        return min(max(clock.elapsed(at: now) / duration, 0), 1)
    }

    var statusTitle: String {
        switch mode {
        case .pomodoro:
            guard phase == .focus else { return phase.title }
            let session = completedFocusSessions % plan.sessionsBeforeLongBreak + 1
            return "Focus · session \(session) of \(plan.sessionsBeforeLongBreak)"
        case .countdown:
            return TimerFormatting.minutes(countdownDuration)
        case .stopwatch:
            return clock.hasStarted ? "Elapsed" : "Ready"
        }
    }

    func select(_ mode: TimerMode) {
        guard mode != self.mode else { return }
        clock.reset()
        stopTicker()
        self.mode = mode
        defaults.set(mode.rawValue, forKey: Keys.mode)
    }

    func toggleRunning() {
        isRunning ? pause() : start()
    }

    func start() {
        now = Date()
        clock.start(at: now)
        startTicker()
    }

    func pause() {
        now = Date()
        clock.pause(at: now)
        stopTicker()
    }

    func reset() {
        clock.reset()
        now = Date()
        stopTicker()
        if mode == .pomodoro {
            phase = .focus
            completedFocusSessions = 0
        }
    }

    /// Ends the current Pomodoro phase early and moves to the next one.
    func skipPhase() {
        guard mode == .pomodoro else { return }
        advancePhase(announce: false)
    }

    func setCountdown(_ duration: TimeInterval) {
        let clamped = min(max(duration, Self.countdownRange.lowerBound), Self.countdownRange.upperBound)
        guard clamped != countdownDuration else { return }
        countdownDuration = clamped
        defaults.set(clamped, forKey: Keys.countdownDuration)
        if mode == .countdown {
            clock.reset()
            stopTicker()
        }
    }

    func adjustCountdown(byMinutes minutes: Int) {
        setCountdown(countdownDuration + TimeInterval(minutes * 60))
    }

    // MARK: - Hydration

    func setHydrationEnabled(_ isEnabled: Bool) {
        isHydrationEnabled = isEnabled
        defaults.set(isEnabled, forKey: Keys.hydrationEnabled)
        scheduleHydration(from: Date())
    }

    func setHydrationInterval(_ interval: TimeInterval) {
        guard Self.hydrationIntervals.contains(interval) else { return }
        hydrationInterval = interval
        defaults.set(interval, forKey: Keys.hydrationInterval)
        scheduleHydration(from: Date())
    }

    // MARK: - Lifecycle

    /// Resumes the hydration schedule saved from the last launch.
    func activate() {
        scheduleHydration(from: Date())
    }

    /// Stops every timer and reminder, for when the module is turned off or Assist quits.
    func deactivate() {
        reset()
        hydrationTimer?.invalidate()
        hydrationTimer = nil
        nextHydrationAt = nil
    }

    // MARK: - Private

    private func startTicker() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        timer.tolerance = 0.1
        ticker = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        now = Date()
        guard let duration, clock.isRunning, clock.elapsed(at: now) >= duration else { return }

        switch mode {
        case .pomodoro:
            advancePhase(announce: true)
        case .countdown:
            clock.reset()
            stopTicker()
            announce(badge: "Time's up", detail: "\(TimerFormatting.minutes(countdownDuration)) timer finished")
        case .stopwatch:
            break
        }
    }

    private func advancePhase(announce shouldAnnounce: Bool) {
        let finished = phase
        if finished == .focus {
            completedFocusSessions += 1
        }
        phase = plan.phase(after: finished, completedFocusSessions: completedFocusSessions)
        clock.reset()
        stopTicker()
        now = Date()

        guard shouldAnnounce else { return }
        if phase == .focus {
            announce(badge: "Focus", detail: "Break over. Start the next focus session.")
        } else {
            announce(badge: "Break time", detail: "\(phase.title): \(TimerFormatting.minutes(plan.duration(of: phase)))")
        }
    }

    private func scheduleHydration(from date: Date) {
        hydrationTimer?.invalidate()
        hydrationTimer = nil
        guard isHydrationEnabled else {
            nextHydrationAt = nil
            return
        }

        let fireDate = date.addingTimeInterval(hydrationInterval)
        nextHydrationAt = fireDate
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hydrationDue()
            }
        }
        timer.tolerance = 5
        hydrationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func hydrationDue() {
        announce(badge: "Hydrate", detail: "Time for some water")
        scheduleHydration(from: Date())
    }

    private func announce(badge: String, detail: String) {
        NSSound(named: NSSound.Name("Glass"))?.play()
        onAlert?(badge, detail)
        DebugLogger.log("modules.timers.alert", ["badge": badge])
    }
}

private enum Keys {
    static let mode = "modules.timers.mode"
    static let countdownDuration = "modules.timers.countdownDuration"
    static let hydrationEnabled = "modules.timers.hydrationEnabled"
    static let hydrationInterval = "modules.timers.hydrationInterval"
}
