import Combine
import Foundation

/// Owns every notch module's service and starts or stops the ones that run
/// in the background (screen time, now playing, timers) as modules are
/// turned on and off.
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

    private var settingsCancellable: AnyCancellable?
    /// Background modules that are currently running.
    private var runningModules: Set<AssistModule> = []

    init(settings: ModuleSettings, directory: URL, defaults: UserDefaults = .standard) {
        self.settings = settings
        shelf = ShelfStore(directory: directory)
        notes = ScratchpadStore(directory: directory)
        timers = FocusTimerService(defaults: defaults)
        calendar = CalendarAgendaService()
        media = NowPlayingService()
        stats = SystemStatsService()
        screenTime = ScreenTimeTracker(directory: directory)
        converter = ImageConversionService(defaults: defaults)
    }

    func start() {
        settingsCancellable = settings.$enabledModules
            .removeDuplicates()
            .sink { [weak self] modules in
                self?.apply(modules)
            }
    }

    func stop() {
        settingsCancellable = nil
        apply([])
    }

    /// Starts modules that were just turned on and stops ones just turned
    /// off, leaving the rest (and, for example, a running hydration
    /// schedule) untouched.
    private func apply(_ modules: [AssistModule]) {
        let backgroundModules: Set<AssistModule> = [.screenTime, .media, .timers]
        let next = Set(modules).intersection(backgroundModules)

        for module in next.subtracting(runningModules) {
            switch module {
            case .screenTime: screenTime.start()
            case .media: media.start()
            case .timers: timers.activate()
            default: break
            }
        }
        for module in runningModules.subtracting(next) {
            switch module {
            case .screenTime: screenTime.stop()
            case .media: media.stop()
            case .timers: timers.deactivate()
            default: break
            }
        }
        runningModules = next

        DebugLogger.log("modules.enabled", ["modules": modules.map(\.rawValue).joined(separator: ",")])
    }
}
