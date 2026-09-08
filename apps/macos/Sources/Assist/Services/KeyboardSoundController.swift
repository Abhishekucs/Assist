import AppKit
import Combine

@MainActor
final class KeyboardSoundController: ObservableObject {
    enum Status: Equatable {
        case off, ready, needsPermission, recording, suspended, failed(String)
    }

    let settings: KeyboardSoundSettings
    let visualizer = KeyboardVisualizerState()
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
    private var audioReady = false

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
            self.visualizer.reset()
            if !self.monitor.hasPermission { self.refresh() }
        }
        self.player.onConfigurationChange = { [weak self] in self?.refresh() }
        settingsSubscription = settings.$configuration.removeDuplicates().sink { [weak self] value in
            guard let self else { return }
            let previous = self.configuration
            self.configuration = value.validated
            if previous.pack != value.pack { self.player.silence() }
            self.player.setVolume(self.configuration.volume)
            if previous.enabled != value.enabled || previous.visualizerEnabled != value.visualizerEnabled {
                self.refresh()
            }
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
        workspace.publisher(for: NSWorkspace.didActivateApplicationNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            // An app switch can consume a shortcut's release events.
            self?.monitor.resetPressedKeys()
            self?.visualizer.reset()
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
        audioReady = false
        visualizer.setVisible(false)
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
        audioReady = false
        if recording || asleep || sessionInactive {
            monitor.stop()
            player.suspend()
            visualizer.setVisible(false)
            status = recording ? .recording : .suspended
        } else if !configuration.enabled && !configuration.visualizerEnabled {
            monitor.stop()
            player.suspend()
            visualizer.setVisible(false)
            status = .off
        } else if !monitor.hasPermission {
            monitor.stop()
            player.suspend()
            visualizer.setVisible(false)
            status = .needsPermission
        } else {
            do {
                try monitor.start()
            } catch {
                monitor.stop()
                player.suspend()
                visualizer.setVisible(false)
                status = .failed(error.localizedDescription)
                return
            }
            visualizer.setVisible(configuration.visualizerEnabled)
            if configuration.enabled {
                do {
                    try player.prepare()
                    audioReady = true
                } catch {
                    failPlayback(error)
                    return
                }
            } else {
                player.suspend()
            }
            status = .ready
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
        guard started, !recording, !asleep, !sessionInactive else { return }
        guard monitor.hasPermission else { refresh(); return }
        visualizer.receive(event)
        guard configuration.enabled, audioReady else { return }
        do {
            try player.play(event, configuration: configuration)
        } catch {
            failPlayback(error)
        }
    }

    private func failPlayback(_ error: any Error) {
        audioReady = false
        player.suspend()
        // Audio and visualization are independent consumers of the same tap.
        if !configuration.visualizerEnabled { monitor.stop() }
        status = .failed(error.localizedDescription)
    }
}
