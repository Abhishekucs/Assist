import Combine
import Foundation

/// Owns notch module services and coordinates their background lifecycle.
@MainActor
final class ModuleServices {
    let settings: ModuleSettings
    let shelf: ShelfStore
    let notes: ScratchpadStore
    let timers: FocusTimerService
    let calendar: CalendarAgendaService
    let media: NowPlayingService
    let stats: SystemStatsService
    let screenTime: ScreenTimeTracker
    let converter: ImageConversionService
    let revenue: RevenueService
    let aiUsage: AIUsageService

    private var settingsCancellable: AnyCancellable?
    /// Background modules that are currently running.
    private var runningModules: Set<AssistModule> = []

    init(
        settings: ModuleSettings,
        directory: URL,
        defaults: UserDefaults = .standard,
        dateProvider: @escaping () -> Date = Date.init,
        stats: SystemStatsService? = nil,
        revenue: RevenueService? = nil,
        aiUsage: AIUsageService? = nil
    ) {
        self.settings = settings
        shelf = ShelfStore(directory: directory)
        notes = ScratchpadStore(directory: directory)
        timers = FocusTimerService(defaults: defaults, dateProvider: dateProvider)
        calendar = CalendarAgendaService()
        media = NowPlayingService()
        self.stats = stats ?? SystemStatsService()
        screenTime = ScreenTimeTracker(directory: directory)
        converter = ImageConversionService(defaults: defaults)
        self.revenue = revenue ?? RevenueService()
        self.aiUsage = aiUsage ?? AIUsageService()
    }

    func start() {
        media.start()
        settingsCancellable = settings.$enabledModules
            .removeDuplicates()
            .sink { [weak self] modules in
                self?.apply(modules)
            }
    }

    func stop() {
        settingsCancellable = nil
        timers.suspend()
        runningModules.remove(.timers)
        apply([])
        media.stop()
    }

    /// Starts modules that were just turned on and stops ones just turned
    /// off, leaving the rest (and, for example, a running hydration
    /// schedule) untouched.
    private func apply(_ modules: [AssistModule]) {
        let backgroundModules: Set<AssistModule> = [.screenTime, .timers]
        let next = Set(modules).intersection(backgroundModules)

        for module in next.subtracting(runningModules) {
            switch module {
            case .screenTime: screenTime.start()
            case .timers: timers.activate()
            default: break
            }
        }
        for module in runningModules.subtracting(next) {
            switch module {
            case .screenTime: screenTime.stop()
            case .timers: timers.deactivate()
            default: break
            }
        }
        runningModules = next

        DebugLogger.log("modules.enabled", ["modules": modules.map(\.rawValue).joined(separator: ",")])
    }
}
