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
    @Published private var clocks = TimerModeClocks()
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
    private let dateProvider: () -> Date
    private var ticker: Timer?
    private var hydrationTimer: Timer?

    init(defaults: UserDefaults = .standard, dateProvider: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.dateProvider = dateProvider
        now = dateProvider()
        mode = defaults.string(forKey: Keys.mode).flatMap(TimerMode.init(rawValue:)) ?? .pomodoro
        let storedCountdown = defaults.double(forKey: Keys.countdownDuration)
        countdownDuration = storedCountdown > 0
            ? min(max(storedCountdown, Self.countdownRange.lowerBound), Self.countdownRange.upperBound)
            : 10 * 60
        isHydrationEnabled = defaults.bool(forKey: Keys.hydrationEnabled)
        let storedInterval = defaults.double(forKey: Keys.hydrationInterval)
        hydrationInterval = Self.hydrationIntervals.contains(storedInterval) ? storedInterval : 45 * 60
        if let data = defaults.data(forKey: Keys.clockState),
           let snapshot = try? JSONDecoder().decode(TimerSnapshot.self, from: data),
           snapshot.isValid {
            clocks = snapshot.clocks
            phase = snapshot.phase
            completedFocusSessions = snapshot.completedFocusSessions
        }
    }

    // MARK: - Timers

    var clock: TimerClock {
        clocks[mode]
    }

    var isRunning: Bool {
        clock.isRunning
    }

    var activeModes: [TimerMode] {
        TimerMode.allCases.filter { clocks[$0].hasStarted }
    }

    func isRunning(_ mode: TimerMode) -> Bool {
        clocks[mode].isRunning
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
        displayTime(for: mode)
    }

    func displayTime(for mode: TimerMode) -> String {
        let elapsed = clocks[mode].elapsed(at: now)
        switch mode {
        case .pomodoro:
            return TimerFormatting.clock(plan.duration(of: phase) - elapsed, roundingUp: true)
        case .countdown:
            return TimerFormatting.clock(countdownDuration - elapsed, roundingUp: true)
        case .stopwatch:
            return TimerFormatting.clock(elapsed)
        }
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
        tick()
        self.mode = mode
        defaults.set(mode.rawValue, forKey: Keys.mode)
    }

    func toggleRunning() {
        isRunning ? pause() : start()
    }

    func start() {
        now = dateProvider()
        clocks[mode].start(at: now)
        saveClocks()
        startTicker()
    }

    func pause() {
        now = dateProvider()
        clocks[mode].pause(at: now)
        saveClocks()
        updateTicker()
    }

    func reset() {
        clocks[mode].reset()
        now = dateProvider()
        updateTicker()
        if mode == .pomodoro {
            phase = .focus
            completedFocusSessions = 0
        }
        saveClocks()
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
        clocks[.countdown].reset()
        saveClocks()
        updateTicker()
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

    /// Reconciles restored deadlines and resumes the module's background work.
    func activate() {
        tick()
        scheduleHydration(from: Date())
    }

    /// Stops background work without changing saved clocks when Assist quits.
    func suspend() {
        stopTicker()
        hydrationTimer?.invalidate()
        hydrationTimer = nil
        nextHydrationAt = nil
    }

    /// Clears timers when the module is explicitly turned off.
    func deactivate() {
        clocks = TimerModeClocks()
        phase = .focus
        completedFocusSessions = 0
        now = dateProvider()
        defaults.removeObject(forKey: Keys.clockState)
        suspend()
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

    private func updateTicker() {
        clocks.hasRunningClock ? startTicker() : stopTicker()
    }

    func tick() {
        now = dateProvider()
        if clocks[.pomodoro].isRunning,
           clocks[.pomodoro].elapsed(at: now) >= plan.duration(of: phase) {
            advancePhase(announce: true)
        }
        if clocks[.countdown].isRunning,
           clocks[.countdown].elapsed(at: now) >= countdownDuration {
            clocks[.countdown].reset()
            saveClocks()
            announce(badge: "Time's up", detail: "\(TimerFormatting.minutes(countdownDuration)) timer finished")
        }
        updateTicker()
    }

    private func advancePhase(announce shouldAnnounce: Bool) {
        let finished = phase
        if finished == .focus {
            completedFocusSessions += 1
        }
        phase = plan.phase(after: finished, completedFocusSessions: completedFocusSessions)
        clocks[.pomodoro].reset()
        saveClocks()
        updateTicker()
        now = dateProvider()

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

    private func saveClocks() {
        let snapshot = TimerSnapshot(clocks: clocks, phase: phase, completedFocusSessions: completedFocusSessions)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Keys.clockState)
        }
    }
}

private struct TimerSnapshot: Codable {
    var clocks: TimerModeClocks
    var phase: PomodoroPhase
    var completedFocusSessions: Int

    var isValid: Bool {
        completedFocusSessions >= 0 && completedFocusSessions < Int.max &&
            [clocks.pomodoro, clocks.countdown, clocks.stopwatch].allSatisfy { clock in
                clock.accumulated.isFinite && clock.accumulated >= 0 &&
                    (clock.startedAt?.timeIntervalSinceReferenceDate.isFinite ?? true)
            }
    }
}

private struct TimerModeClocks: Codable {
    var pomodoro = TimerClock()
    var countdown = TimerClock()
    var stopwatch = TimerClock()

    subscript(mode: TimerMode) -> TimerClock {
        get {
            switch mode {
            case .pomodoro: pomodoro
            case .countdown: countdown
            case .stopwatch: stopwatch
            }
        }
        set {
            switch mode {
            case .pomodoro: pomodoro = newValue
            case .countdown: countdown = newValue
            case .stopwatch: stopwatch = newValue
            }
        }
    }

    var hasRunningClock: Bool {
        pomodoro.isRunning || countdown.isRunning || stopwatch.isRunning
    }
}

private enum Keys {
    static let mode = "modules.timers.mode"
    static let clockState = "modules.timers.clockState"
    static let countdownDuration = "modules.timers.countdownDuration"
    static let hydrationEnabled = "modules.timers.hydrationEnabled"
    static let hydrationInterval = "modules.timers.hydrationInterval"
}
