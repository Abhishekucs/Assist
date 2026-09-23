import AppKit
import Combine

/// Records how long each app is frontmost, while the Screen Time module is on.
/// Time stops counting when the display sleeps, the Mac sleeps, the session
/// switches away, or no input arrives for five minutes. The ledger is stored
/// only in Assist's Application Support folder.
@MainActor
final class ScreenTimeTracker: ObservableObject {
    static let commitInterval: TimeInterval = 60
    static let idleThreshold: TimeInterval = 5 * 60

    @Published private(set) var ledger = ScreenTimeLedger()
    @Published private(set) var isTracking = false

    private struct Segment {
        let bundleIdentifier: String
        let name: String
        var since: Date
    }

    private let fileURL: URL
    private let calendar = Calendar.current
    private var canPersist = true
    private var segment: Segment?
    private var isPaused = false
    private var commitTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var iconCache: [String: NSImage] = [:]

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("screen-time.json", isDirectory: false)
        switch ModuleStorage.load(ScreenTimeLedger.self, from: fileURL) {
        case .missing:
            break
        case let .loaded(saved):
            ledger = saved
        case .unreadable:
            canPersist = false
        }
    }

    func start() {
        guard !isTracking else { return }
        isTracking = true
        isPaused = false
        observeWorkspace()
        beginSegment(for: NSWorkspace.shared.frontmostApplication, at: Date())

        let timer = Timer(timeInterval: Self.commitInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.commit()
            }
        }
        timer.tolerance = 5
        commitTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        DebugLogger.log("modules.screen-time.start")
    }

    func stop() {
        guard isTracking else { return }
        commit()
        isTracking = false
        segment = nil
        commitTimer?.invalidate()
        commitTimer = nil
        cancellables.removeAll()
        DebugLogger.log("modules.screen-time.stop")
    }

    /// Counts the current app's time so far, so what is shown is up to date.
    func flush() {
        guard isTracking, !isPaused else { return }
        commit()
    }

    /// Clears every recorded day.
    func reset() {
        ledger = ScreenTimeLedger()
        // Time already spent in the current app belongs to the cleared history.
        segment?.since = Date()
        persist()
    }

    func entries(on day: Date = Date()) -> [ScreenTimeEntry] {
        ledger.entries(on: day, calendar: calendar)
    }

    func total(on day: Date = Date()) -> TimeInterval {
        ledger.total(on: day, calendar: calendar)
    }

    func icon(for bundleIdentifier: String) -> NSImage? {
        if let cached = iconCache[bundleIdentifier] {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[bundleIdentifier] = icon
        return icon
    }

    // MARK: - Private

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter

        center.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated {
                    self?.applicationActivated(application)
                }
            }
            .store(in: &cancellables)

        let pauses: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.willSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ]
        for name in pauses {
            center.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.pause()
                    }
                }
                .store(in: &cancellables)
        }

        let resumes: [Notification.Name] = [
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.didWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]
        for name in resumes {
            center.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.resume()
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func applicationActivated(_ application: NSRunningApplication?) {
        guard isTracking, !isPaused else { return }
        let now = Date()
        commit(until: now)
        beginSegment(for: application, at: now)
    }

    private func pause() {
        guard isTracking, !isPaused else { return }
        commit()
        isPaused = true
        segment = nil
    }

    private func resume() {
        guard isTracking, isPaused else { return }
        isPaused = false
        beginSegment(for: NSWorkspace.shared.frontmostApplication, at: Date())
    }

    private func beginSegment(for application: NSRunningApplication?, at date: Date) {
        guard let application, let bundleIdentifier = application.bundleIdentifier else {
            segment = nil
            return
        }
        segment = Segment(
            bundleIdentifier: bundleIdentifier,
            name: application.localizedName ?? bundleIdentifier,
            since: date
        )
    }

    /// Adds the current app's time up to now, leaving out input-idle time
    /// beyond the idle threshold.
    private func commit() {
        let now = Date()
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )
        let activeUntil = idle >= Self.idleThreshold ? now.addingTimeInterval(-idle) : now
        commit(until: activeUntil)
        segment?.since = now
    }

    private func commit(until end: Date) {
        guard let segment else { return }
        if end > segment.since {
            ledger.record(
                from: segment.since,
                to: end,
                bundleIdentifier: segment.bundleIdentifier,
                name: segment.name,
                calendar: calendar
            )
            ledger.prune()
            persist()
        }
        self.segment?.since = max(segment.since, end)
    }

    private func persist() {
        guard canPersist else { return }
        ModuleStorage.save(ledger, to: fileURL)
    }
}
