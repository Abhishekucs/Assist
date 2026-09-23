import XCTest
@testable import Assist

final class FocusTimerServiceTests: XCTestCase {
    @MainActor
    func testTimerAlertsReplacePriorAlertAndExpandCollapsedChrome() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        let settings = PillSettings(defaults: defaults)
        let voice = VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        let viewModel = PillViewModel(settings: settings, voiceContextService: voice)

        viewModel.showTimerAlert(badge: "Hydrate", detail: "Time for some water")
        let first = try XCTUnwrap(viewModel.timerAlert)
        XCTAssertEqual(first.badge, "Hydrate")
        XCTAssertEqual(first.detail, "Time for some water")
        XCTAssertGreaterThan(PillChromeMetrics.timerAlertSize(settings: settings).width, PillChromeMetrics.collapsedSize(settings: settings).width)
        XCTAssertGreaterThan(PillChromeMetrics.timerAlertSize(settings: settings).height, PillChromeMetrics.collapsedSize(settings: settings).height)

        viewModel.showTimerAlert(badge: "Break time", detail: "Short break: 5 min")
        XCTAssertNotEqual(viewModel.timerAlert?.id, first.id)
        XCTAssertEqual(viewModel.timerAlert?.badge, "Break time")
    }

    @MainActor
    func testModuleStopAndRestartRestoresRunningAndPausedModes() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var date = Date(timeIntervalSinceReferenceDate: 1_000)
        let settings = ModuleSettings(defaults: defaults)
        settings.setEnabled(.timers, true)
        var modules: ModuleServices? = ModuleServices(settings: settings, directory: directory, defaults: defaults, dateProvider: { date })
        modules?.start()
        modules?.timers.skipPhase()
        modules?.timers.start()
        modules?.timers.select(.countdown)
        modules?.timers.setCountdown(10 * 60)
        modules?.timers.start()
        date.addTimeInterval(40)
        modules?.timers.pause()
        modules?.timers.select(.stopwatch)
        modules?.timers.start()
        modules?.stop()
        modules = nil

        date.addTimeInterval(20)
        let restored = ModuleServices(settings: ModuleSettings(defaults: defaults), directory: directory, defaults: defaults, dateProvider: { date })
        restored.start()
        defer { restored.stop() }
        XCTAssertEqual(restored.timers.mode, .stopwatch)
        XCTAssertTrue(restored.timers.isRunning)
        XCTAssertEqual(restored.timers.clock.elapsed(at: date), 20)
        restored.timers.select(.countdown)
        XCTAssertFalse(restored.timers.isRunning)
        XCTAssertEqual(restored.timers.clock.elapsed(at: date), 40)
        XCTAssertEqual(restored.timers.displayTime, "9:20")
        restored.timers.select(.pomodoro)
        XCTAssertEqual(restored.timers.phase, .shortBreak)
        XCTAssertEqual(restored.timers.completedFocusSessions, 1)
        XCTAssertTrue(restored.timers.isRunning)
        XCTAssertEqual(restored.timers.displayTime, "4:00")
    }

    @MainActor
    func testRestartReconcilesExpiredInactiveCountdownAndFocusPhase() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        var date = Date(timeIntervalSinceReferenceDate: 1_000)
        let timers = FocusTimerService(defaults: defaults, dateProvider: { date })
        timers.start()
        timers.select(.countdown)
        timers.setCountdown(60)
        timers.start()
        timers.select(.stopwatch)
        timers.start()
        timers.suspend()

        date.addTimeInterval(100)
        let restored = FocusTimerService(defaults: defaults, dateProvider: { date })
        defer { restored.deactivate() }
        var alerts: [String] = []
        restored.onAlert = { badge, _ in alerts.append(badge) }
        restored.activate()

        XCTAssertEqual(alerts, ["Time's up"])
        XCTAssertTrue(restored.isRunning)
        XCTAssertEqual(restored.clock.elapsed(at: date), 100)
        restored.select(.countdown)
        XCTAssertFalse(restored.clock.hasStarted)
        restored.select(.pomodoro)
        XCTAssertEqual(restored.displayTime, "23:20")

        date.addTimeInterval(1_500)
        restored.tick()
        XCTAssertEqual(alerts, ["Time's up", "Break time"])
        XCTAssertEqual(restored.phase, .shortBreak)
        XCTAssertEqual(restored.completedFocusSessions, 1)
        XCTAssertEqual(restored.displayTime, "5:00")
        restored.suspend()

        let nextLaunch = FocusTimerService(defaults: defaults, dateProvider: { date })
        defer { nextLaunch.deactivate() }
        nextLaunch.activate()
        XCTAssertEqual(nextLaunch.phase, .shortBreak)
        XCTAssertEqual(nextLaunch.completedFocusSessions, 1)
        XCTAssertFalse(nextLaunch.clock.hasStarted)
    }

    @MainActor
    func testExplicitModuleDisableClearsPersistedClockState() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = ModuleSettings(defaults: defaults)
        settings.setEnabled(.timers, true)
        let modules = ModuleServices(settings: settings, directory: directory, defaults: defaults)
        modules.start()
        modules.timers.start()
        modules.timers.select(.stopwatch)
        modules.timers.start()
        settings.setEnabled(.timers, false)
        modules.stop()

        let restored = FocusTimerService(defaults: defaults)
        defer { restored.deactivate() }
        XCTAssertFalse(restored.clock.hasStarted)
        restored.select(.pomodoro)
        XCTAssertFalse(restored.clock.hasStarted)
    }

    @MainActor
    func testSwitchingPreservesIndependentRunningAndPausedClocks() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        var date = Date(timeIntervalSinceReferenceDate: 1_000)
        let timers = FocusTimerService(defaults: defaults, dateProvider: { date })
        defer { timers.deactivate() }

        timers.start()
        date.addTimeInterval(60)
        timers.select(.countdown)
        XCTAssertEqual(timers.displayTime, "10:00")
        timers.setCountdown(5 * 60)
        timers.start()

        date.addTimeInterval(90)
        timers.select(.stopwatch)
        timers.start()
        date.addTimeInterval(30)
        timers.select(.pomodoro)
        XCTAssertEqual(timers.activeModes, [.pomodoro, .countdown, .stopwatch])
        XCTAssertEqual(timers.displayTime(for: .pomodoro), "22:00")
        XCTAssertEqual(timers.displayTime(for: .countdown), "3:00")
        XCTAssertEqual(timers.displayTime(for: .stopwatch), "0:30")
        XCTAssertTrue(timers.isRunning)
        XCTAssertEqual(timers.clock.elapsed(at: date), 180)
        XCTAssertEqual(timers.displayTime, "22:00")
        XCTAssertEqual(timers.progress, 180.0 / (25 * 60))

        timers.pause()
        XCTAssertEqual(timers.activeModes, [.pomodoro, .countdown, .stopwatch])
        XCTAssertFalse(timers.isRunning(.pomodoro))
        XCTAssertTrue(timers.isRunning(.countdown))
        date.addTimeInterval(30)
        timers.select(.countdown)
        XCTAssertTrue(timers.isRunning)
        XCTAssertEqual(timers.clock.elapsed(at: date), 150)
        XCTAssertEqual(timers.displayTime, "2:30")
        XCTAssertEqual(timers.countdownDuration, 5 * 60)
        timers.pause()

        timers.select(.stopwatch)
        XCTAssertEqual(timers.clock.elapsed(at: date), 60)
        timers.reset()
        XCTAssertEqual(timers.activeModes, [.pomodoro, .countdown])
        timers.select(.pomodoro)
        XCTAssertFalse(timers.isRunning)
        XCTAssertEqual(timers.clock.elapsed(at: date), 180)
        timers.select(.countdown)
        XCTAssertFalse(timers.isRunning)
        XCTAssertEqual(timers.clock.elapsed(at: date), 150)
    }

    @MainActor
    func testInactiveFocusCompletesWithoutStoppingOtherRunningModes() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        var date = Date(timeIntervalSinceReferenceDate: 1_000)
        let timers = FocusTimerService(defaults: defaults, dateProvider: { date })
        defer { timers.deactivate() }
        var alerts: [String] = []
        timers.onAlert = { badge, _ in alerts.append(badge) }

        timers.start()
        timers.select(.stopwatch)
        timers.start()
        date.addTimeInterval(timers.plan.focus)
        timers.tick()

        XCTAssertEqual(alerts, ["Break time"])
        XCTAssertEqual(timers.phase, .shortBreak)
        XCTAssertEqual(timers.completedFocusSessions, 1)
        XCTAssertTrue(timers.isRunning)
        XCTAssertEqual(timers.clock.elapsed(at: date), timers.plan.focus)
        timers.select(.pomodoro)
        XCTAssertEqual(timers.displayTime, "5:00")
        XCTAssertEqual(timers.statusTitle, "Short break")
        XCTAssertFalse(timers.clock.hasStarted)

        timers.select(.stopwatch)
        timers.select(.pomodoro)
        XCTAssertEqual(timers.completedFocusSessions, 1)
        XCTAssertEqual(timers.phase, .shortBreak)
    }

    @MainActor
    func testInactiveCountdownCompletesWithoutStoppingFocus() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        var date = Date(timeIntervalSinceReferenceDate: 1_000)
        let timers = FocusTimerService(defaults: defaults, dateProvider: { date })
        defer { timers.deactivate() }
        var alerts: [String] = []
        timers.onAlert = { badge, _ in alerts.append(badge) }

        timers.select(.countdown)
        timers.setCountdown(5 * 60)
        timers.start()
        timers.select(.pomodoro)
        timers.start()
        date.addTimeInterval(5 * 60)
        timers.tick()

        XCTAssertEqual(alerts, ["Time's up"])
        XCTAssertTrue(timers.isRunning)
        XCTAssertEqual(timers.clock.elapsed(at: date), 5 * 60)
        timers.select(.countdown)
        XCTAssertFalse(timers.clock.hasStarted)
        XCTAssertEqual(timers.displayTime, "5:00")
        XCTAssertEqual(timers.countdownDuration, 5 * 60)
        timers.select(.pomodoro)
        XCTAssertEqual(timers.displayTime, "20:00")
    }

    @MainActor
    func testSwitchAfterFocusDeadlineAdvancesBeforeShowingOtherMode() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        var date = Date(timeIntervalSinceReferenceDate: 1_000)
        let timers = FocusTimerService(defaults: defaults, dateProvider: { date })
        defer { timers.deactivate() }
        var alerts: [String] = []
        timers.onAlert = { badge, _ in alerts.append(badge) }

        timers.start()
        date.addTimeInterval(timers.plan.focus + 2)
        timers.select(.countdown)

        XCTAssertEqual(alerts, ["Break time"])
        XCTAssertEqual(timers.completedFocusSessions, 1)
        timers.select(.pomodoro)
        XCTAssertEqual(timers.phase, .shortBreak)
        XCTAssertEqual(timers.displayTime, "5:00")
    }

    @MainActor
    func testResetAndDeactivationClearEveryClockButRetainCountdownSetting() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }
        var date = Date(timeIntervalSinceReferenceDate: 1_000)
        let timers = FocusTimerService(defaults: defaults, dateProvider: { date })

        timers.skipPhase()
        XCTAssertEqual(timers.completedFocusSessions, 1)
        timers.start()
        timers.select(.countdown)
        timers.setCountdown(15 * 60)
        timers.start()
        timers.reset()
        timers.select(.pomodoro)
        XCTAssertEqual(timers.phase, .shortBreak)
        XCTAssertEqual(timers.completedFocusSessions, 1)
        XCTAssertTrue(timers.isRunning)

        date.addTimeInterval(20)
        timers.deactivate()
        XCTAssertFalse(timers.clock.hasStarted)
        XCTAssertEqual(timers.phase, .focus)
        XCTAssertEqual(timers.completedFocusSessions, 0)
        timers.select(.countdown)
        XCTAssertFalse(timers.clock.hasStarted)
        XCTAssertEqual(timers.countdownDuration, 15 * 60)
    }

    private func makeDefaults() throws -> (UserDefaults, () -> Void) {
        let suite = "Assist.FocusTimerServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (defaults, { defaults.removePersistentDomain(forName: suite) })
    }
}
