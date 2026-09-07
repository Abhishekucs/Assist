import AppKit
import Combine

@MainActor
final class KeyboardSoundController: ObservableObject {
    enum Status: Equatable {
        case off, ready, needsPermission, recording, suspended, failed(String)
    }

    let settings: KeyboardSoundSettings
    @Published private(set) var status: Status = .off
    @Published private(set) var previewError: String?
    private let monitor: any KeyboardEventMonitoring
    private let player: any KeyboardSoundPlaying
    private var configuration: KeyboardSoundConfiguration
    private var subscriptions: Set<AnyCancellable> = []
    private var settingsSubscription: AnyCancellable?
    private var started = false
    private var recording = false
    private var asleep = false
    private var sessionInactive = false

    init(settings: KeyboardSoundSettings,
         monitor: (any KeyboardEventMonitoring)? = nil,
         player: (any KeyboardSoundPlaying)? = nil) {
        self.settings = settings
        self.monitor = monitor ?? KeyboardEventMonitor()
        self.player = player ?? KeyboardSoundEngine()
        configuration = settings.configuration.validated
        self.monitor.onEvent = { [weak self] event in self?.receive(event) }
        self.monitor.onInterruption = { [weak self] in
            guard let self else { return }
            self.player.silence()
            if !self.monitor.hasPermission { self.refresh() }
        }
        self.player.onConfigurationChange = { [weak self] in self?.refresh() }
        settingsSubscription = settings.$configuration.removeDuplicates().sink { [weak self] value in
            guard let self else { return }
            let previous = self.configuration
            self.configuration = value.validated
            if previous.pack != value.pack { self.player.silence() }
            self.player.setVolume(self.configuration.volume)
            if previous.enabled != value.enabled { self.refresh() }
        }
    }

    func start(voiceContext: VoiceContextService) {
        guard !started else { return }
        started = true
        voiceContext.$isRecording.removeDuplicates().sink { [weak self] value in
            self?.setRecording(value)
        }.store(in: &subscriptions)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.publisher(for: NSWorkspace.willSleepNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.asleep = true; self?.refresh()
        }.store(in: &subscriptions)
        workspace.publisher(for: NSWorkspace.didWakeNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.asleep = false; self?.refresh()
        }.store(in: &subscriptions)
        workspace.publisher(for: NSWorkspace.sessionDidResignActiveNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.sessionInactive = true; self?.refresh()
        }.store(in: &subscriptions)
        workspace.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.sessionInactive = false; self?.refresh()
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.refresh()
        }.store(in: &subscriptions)
        refresh()
    }

    func stop() {
        started = false
        monitor.stop()
        player.suspend()
        subscriptions.removeAll()
        status = .off
    }

    func setRecording(_ value: Bool) {
        recording = value
        if value { previewError = nil }
        refresh()
    }

    func requestPermission() {
        monitor.requestPermission()
        refresh()
        if !monitor.hasPermission { openInputSettings() }
    }

    func openInputSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        previewError = nil
        guard started else { return }
        if recording || asleep || sessionInactive {
            monitor.stop()
            player.suspend()
            status = recording ? .recording : .suspended
        } else if !configuration.enabled {
            monitor.stop()
            player.suspend()
            status = .off
        } else if !monitor.hasPermission {
            monitor.stop()
            player.suspend()
            status = .needsPermission
        } else {
            do {
                try player.prepare()
                try monitor.start()
                status = .ready
            } catch {
                monitor.stop()
                player.suspend()
                status = .failed(error.localizedDescription)
            }
        }
    }

    func preview(_ pack: KeyboardSoundPack) {
        guard started, !recording, !asleep, !sessionInactive else { return }
        do {
            previewError = nil
            try player.preview(pack, configuration: configuration)
        } catch { previewError = error.localizedDescription }
    }

    private func receive(_ event: KeyboardSoundEvent) {
        guard started, configuration.enabled, !recording, !asleep, !sessionInactive,
              monitor.hasPermission else { return }
        do {
            try player.play(event, configuration: configuration)
        } catch {
            monitor.stop()
            player.suspend()
            status = .failed(error.localizedDescription)
        }
    }
}
