import AppKit
import KeyboardAudioRender
import XCTest
@testable import Assist

final class KeyboardSoundTests: XCTestCase {
    func testPhysicalPressStateIgnoresRepeatDuplicateDownAndOrphanRelease() {
        var state = KeyboardPressState()
        XCTAssertNil(state.event(keyCode: 0, isDown: false))
        XCTAssertNotNil(state.event(keyCode: 0, isDown: true))
        XCTAssertNil(state.event(keyCode: 0, isDown: true))
        XCTAssertNil(state.event(keyCode: 0, isDown: true, isRepeat: true))
        XCTAssertNotNil(state.event(keyCode: 0, isDown: false))
        XCTAssertTrue(state.pressed.isEmpty)
        _ = state.event(keyCode: 1, isDown: true)
        state.reset()
        XCTAssertNil(state.event(keyCode: 1, isDown: false))
    }

    func testStereoAndSpecialKeyMappings() {
        XCTAssertLessThan(KeyboardSoundEvent(keyCode: 0, phase: .down).pan, 0)
        XCTAssertGreaterThan(KeyboardSoundEvent(keyCode: 35, phase: .down).pan, 0)
        XCTAssertEqual(KeyboardSoundEvent(keyCode: 49, phase: .down).pan, 0)
        for pack in KeyboardSoundPack.allCases {
            XCTAssertEqual(KeyboardSoundEvent(keyCode: 49, phase: .down).sampleIndex(pack: pack, variation: 2), pack.sampleOffset + 3)
            XCTAssertEqual(KeyboardSoundEvent(keyCode: 36, phase: .up).sampleIndex(pack: pack, variation: 0), pack.sampleOffset + 10)
            XCTAssertEqual(KeyboardSoundEvent(keyCode: 117, phase: .down).sampleIndex(pack: pack, variation: 1), pack.sampleOffset + 5)
        }
    }

    @MainActor
    func testSettingsPersistAndValidateWithoutEnablingOnFreshInstall() throws {
        let defaults = makeDefaults()
        let settings = KeyboardSoundSettings(defaults: defaults)
        XCTAssertFalse(settings.configuration.enabled)
        settings.configuration = .init(enabled: true, pack: .clicky, volume: 1.8, stereo: false)
        let loaded = KeyboardSoundSettings(defaults: defaults).configuration
        XCTAssertTrue(loaded.enabled)
        XCTAssertEqual(loaded.pack, .clicky)
        XCTAssertEqual(loaded.volume, 1)
        XCTAssertFalse(loaded.stereo)
        defaults.set(Data("invalid".utf8), forKey: KeyboardSoundSettings.defaultsKey)
        XCTAssertFalse(KeyboardSoundSettings(defaults: defaults).configuration.enabled)
    }

    func testAllFourBundledPacksRenderNonSilentFiniteAudio() throws {
        let storage = try KeyboardSoundRenderStorage()
        try storage.loadSamples()
        for index in 0..<48 {
            keyboard_audio_reset(storage.pointer)
            XCTAssertTrue(keyboard_audio_enqueue(storage.pointer, UInt32(index), 1, 0, 1))
            let (left, right) = render(storage.pointer, frames: 24_000)
            XCTAssertTrue(left.allSatisfy { $0.isFinite && abs($0) < 1 })
            XCTAssertGreaterThan(left.map(abs).max() ?? 0, 0.002, "Silent sample \(index)")
            XCTAssertEqual(left, right)
        }
    }

    func testRendererMixesOverlappingHitsAndPans() throws {
        let r = try makeRenderer()
        defer { keyboard_audio_destroy(r) }
        keyboard_audio_set_volume(r, 1)
        XCTAssertTrue(keyboard_audio_enqueue(r, 0, 1, -1, 1))
        let single = render(r, frames: 8)
        XCTAssertGreaterThan(single.0[0], 0)
        XCTAssertEqual(single.1[0], 0, accuracy: 0.00001)
        keyboard_audio_reset(r)
        XCTAssertTrue(keyboard_audio_enqueue(r, 0, 1, -1, 1))
        XCTAssertTrue(keyboard_audio_enqueue(r, 0, 1, -1, 1))
        let double = render(r, frames: 8)
        XCTAssertGreaterThan(double.0[0], single.0[0])
        XCTAssertLessThan(double.0[0], 1)
    }

    func testResetCancelsQueuedAndAudibleTailsAndScheduledRelease() throws {
        let r = try makeRenderer()
        defer { keyboard_audio_destroy(r) }
        XCTAssertTrue(keyboard_audio_enqueue(r, 0, 1, 0, 1))
        XCTAssertTrue(keyboard_audio_enqueue_after(r, 0, 1, 0, 1, 16))
        _ = render(r, frames: 8)
        keyboard_audio_reset(r)
        XCTAssertTrue(render(r, frames: 64).0.allSatisfy { $0 == 0 })
        XCTAssertTrue(keyboard_audio_enqueue(r, 0, 1, 0, 1))
        keyboard_audio_reset(r)
        XCTAssertTrue(render(r, frames: 64).0.allSatisfy { $0 == 0 })
    }

    func testPreviewReleaseUsesAudioFrameTiming() throws {
        let r = try makeRenderer()
        defer { keyboard_audio_destroy(r) }
        XCTAssertTrue(keyboard_audio_enqueue_after(r, 0, 1, 0, 1, 12))
        let output = render(r, frames: 32).0
        XCTAssertTrue(output.prefix(12).allSatisfy { $0 == 0 })
        XCTAssertGreaterThan(output[12], 0)
    }

    func testBoundedQueueAndInvalidCommandsDoNotCorruptRenderer() throws {
        let r = try makeRenderer()
        defer { keyboard_audio_destroy(r) }
        XCTAssertFalse(keyboard_audio_enqueue(r, 1, 1, 0, 1))
        XCTAssertFalse(keyboard_audio_enqueue(r, 0, .nan, 0, 1))
        XCTAssertFalse(keyboard_audio_enqueue(r, 0, 1, 0, 0))
        var accepted = 0
        for _ in 0..<1000 { if keyboard_audio_enqueue(r, 0, 1, 0, 1) { accepted += 1 } }
        XCTAssertEqual(accepted, 255)
        XCTAssertTrue(render(r, frames: 512).0.allSatisfy { $0.isFinite && abs($0) < 1 })
        XCTAssertTrue(keyboard_audio_enqueue(r, 0, 1, 0, 1))
        keyboard_audio_set_volume(r, .nan)
        XCTAssertTrue(render(r, frames: 16).0.allSatisfy { $0 == 0 })
    }

    @MainActor
    func testPreviewWorksWithoutPermissionOrEnablingGlobalListening() {
        let (controller, monitor, player) = makeController(permission: false)
        controller.preview(.soft)
        XCTAssertEqual(player.previews, [.soft])
        XCTAssertEqual(monitor.starts, 0)
        XCTAssertEqual(controller.status, .off)
        controller.settings.configuration.enabled = true
        XCTAssertEqual(controller.status, .needsPermission)
        XCTAssertEqual(monitor.starts, 0)
        controller.stop()
    }

    @MainActor
    func testRecordingAndDisableSuppressEventsAndPreviewsWithoutLosingPreference() {
        let (controller, monitor, player) = makeController(permission: true)
        controller.settings.configuration.enabled = true
        XCTAssertEqual(controller.status, .ready)
        monitor.onEvent?(.init(keyCode: 0, phase: .down))
        XCTAssertEqual(player.hits, 1)
        controller.setRecording(true)
        XCTAssertEqual(controller.status, .recording)
        monitor.onEvent?(.init(keyCode: 1, phase: .down))
        controller.preview(.thock)
        XCTAssertEqual(player.hits, 1)
        XCTAssertTrue(player.previews.isEmpty)
        XCTAssertTrue(controller.settings.configuration.enabled)
        controller.setRecording(false)
        XCTAssertEqual(controller.status, .ready)
        controller.settings.configuration.enabled = false
        monitor.onEvent?(.init(keyCode: 2, phase: .down))
        XCTAssertEqual(player.hits, 1)
        XCTAssertEqual(controller.status, .off)
        controller.stop()
    }

    @MainActor
    func testPermissionRevocationAndRegrantRequireAHealthyMonitor() {
        let (controller, monitor, player) = makeController(permission: true)
        controller.settings.configuration.enabled = true
        monitor.hasPermission = false
        monitor.onInterruption?()
        XCTAssertEqual(controller.status, .needsPermission)
        XCTAssertGreaterThan(player.suspends, 0)
        monitor.hasPermission = true
        controller.refresh()
        XCTAssertEqual(controller.status, .ready)
        monitor.failStart = true
        controller.refresh()
        guard case .failed = controller.status else { return XCTFail("Must surface tap failure") }
        controller.stop()
    }

    @MainActor
    func testVoiceOwnerMutesBeforeMicrophoneStartAndRestoresAfterFailureOrCancel() throws {
        let monitor = KeyboardMonitorSpy()
        let player = KeyboardPlayerSpy()
        let controller = KeyboardSoundController(settings: KeyboardSoundSettings(defaults: makeDefaults()), monitor: monitor, player: player)
        let recorder = KeyboardVoiceRecorderSpy()
        let voice = VoiceContextService(audioRecorder: recorder, modelStateOverride: .ready, microphoneAccessStateOverride: .authorized)
        controller.start(voiceContext: voice)
        controller.settings.configuration.enabled = true
        recorder.onStart = { XCTAssertEqual(controller.status, .recording) }
        recorder.failStart = true
        XCTAssertThrowsError(try voice.startRecording(sessionID: UUID()))
        XCTAssertFalse(voice.isRecording)
        XCTAssertEqual(controller.status, .ready)
        recorder.failStart = false
        XCTAssertTrue(voice.prepareAudioInput())
        let session = UUID()
        try voice.startRecording(sessionID: session)
        XCTAssertEqual(controller.status, .recording)
        voice.cancelRecording(sessionID: UUID())
        XCTAssertEqual(controller.status, .recording)
        voice.cancelRecording(sessionID: session)
        XCTAssertEqual(controller.status, .ready)
        controller.stop()
    }

    @MainActor
    func testVisualizerRunsWithSoundsOffAndDoesNotPrepareAudio() {
        let (controller, monitor, player) = makeController(permission: true)
        controller.settings.configuration.visualizerEnabled = true
        XCTAssertEqual(controller.status, .ready)
        XCTAssertTrue(controller.visualizer.isVisible)
        XCTAssertEqual(player.prepares, 0)
        monitor.onEvent?(.init(keyCode: 0, phase: .down))
        XCTAssertEqual(controller.visualizer.pressedKeys, [0])
        XCTAssertEqual(player.hits, 0)
        controller.settings.configuration.enabled = true
        monitor.onEvent?(.init(keyCode: 49, phase: .down))
        XCTAssertEqual(player.hits, 1)
        XCTAssertEqual(controller.visualizer.pressedKeys, [0, 49])
        controller.settings.configuration.visualizerEnabled = false
        XCTAssertFalse(controller.visualizer.isVisible)
        XCTAssertTrue(controller.visualizer.pressedKeys.isEmpty)
        monitor.onEvent?(.init(keyCode: 49, phase: .up))
        XCTAssertEqual(player.hits, 2)
        controller.settings.configuration.enabled = false
        XCTAssertEqual(controller.status, .off)
        XCTAssertFalse(monitor.isRunning)
        controller.stop()
    }

    @MainActor
    func testVisualizerResetsOnInterruptionRecordingAndPermissionLoss() {
        let (controller, monitor, _) = makeController(permission: true)
        controller.settings.configuration.visualizerEnabled = true
        monitor.onEvent?(.init(keyCode: 55, phase: .down))
        monitor.onInterruption?()
        XCTAssertTrue(controller.visualizer.pressedKeys.isEmpty)
        monitor.onEvent?(.init(keyCode: 0, phase: .down))
        controller.setRecording(true)
        XCTAssertFalse(controller.visualizer.isVisible)
        XCTAssertTrue(controller.visualizer.pressedKeys.isEmpty)
        monitor.onEvent?(.init(keyCode: 1, phase: .down))
        XCTAssertTrue(controller.visualizer.pressedKeys.isEmpty)
        controller.setRecording(false)
        XCTAssertTrue(controller.visualizer.isVisible)
        monitor.onEvent?(.init(keyCode: 0, phase: .down))
        monitor.hasPermission = false
        monitor.onInterruption?()
        XCTAssertFalse(controller.visualizer.isVisible)
        XCTAssertTrue(controller.visualizer.pressedKeys.isEmpty)
        XCTAssertEqual(controller.status, .needsPermission)
        monitor.hasPermission = true
        controller.refresh()
        XCTAssertTrue(controller.visualizer.isVisible)
        XCTAssertTrue(controller.visualizer.pressedKeys.isEmpty)
        controller.stop()
        XCTAssertFalse(controller.visualizer.isVisible)
        controller.start(voiceContext: VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined))
        XCTAssertTrue(controller.visualizer.isVisible)
        controller.settings.configuration.visualizerEnabled = false
        XCTAssertFalse(controller.visualizer.isVisible)
        controller.stop()
    }

    @MainActor
    func testAudioFailureDoesNotStopEnabledVisualizer() {
        let (controller, monitor, player) = makeController(permission: true)
        controller.settings.configuration.visualizerEnabled = true
        player.failPrepare = true
        controller.settings.configuration.enabled = true
        guard case .failed = controller.status else { return XCTFail("Audio error must be surfaced") }
        XCTAssertTrue(controller.visualizer.isVisible)
        XCTAssertTrue(monitor.isRunning)
        monitor.onEvent?(.init(keyCode: 0, phase: .down))
        XCTAssertEqual(controller.visualizer.pressedKeys, [0])
        XCTAssertEqual(player.hits, 0)
        player.failPrepare = false
        controller.refresh()
        player.failPlay = true
        monitor.onEvent?(.init(keyCode: 0, phase: .up))
        XCTAssertTrue(controller.visualizer.pressedKeys.isEmpty)
        XCTAssertTrue(monitor.isRunning)
        controller.stop()
    }

    @MainActor
    private func makeController(permission: Bool) -> (KeyboardSoundController, KeyboardMonitorSpy, KeyboardPlayerSpy) {
        let monitor = KeyboardMonitorSpy()
        monitor.hasPermission = permission
        let player = KeyboardPlayerSpy()
        let controller = KeyboardSoundController(settings: KeyboardSoundSettings(defaults: makeDefaults()), monitor: monitor, player: player)
        let voice = VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        controller.start(voiceContext: voice)
        return (controller, monitor, player)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "Assist.KeyboardSoundTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return defaults
    }

    private func makeRenderer() throws -> OpaquePointer {
        let r = try XCTUnwrap(keyboard_audio_create(1))
        let samples: [Float] = Array(repeating: 0.25, count: 256)
        XCTAssertTrue(samples.withUnsafeBufferPointer { keyboard_audio_set_sample(r, 0, $0.baseAddress, UInt32($0.count)) })
        return r
    }

    private func render(_ r: OpaquePointer, frames: Int) -> ([Float], [Float]) {
        var left = [Float](repeating: 0, count: frames)
        var right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { rr in
                keyboard_audio_render(r, l.baseAddress, rr.baseAddress, UInt32(frames))
            }
        }
        return (left, right)
    }
}

@MainActor
private final class KeyboardVoiceRecorderSpy: VoiceAudioRecording {
    var onStart: (() -> Void)?
    var failStart = false
    func prepare() throws {}
    func start(callback: @escaping ([Float]) -> Void) throws {
        onStart?()
        if failStart { throw KeyboardSoundError.rendererUnavailable }
    }
    func pause() {}
    func stop() {}
    func takeSamples() -> ContiguousArray<Float> { [] }
}

@MainActor
private final class KeyboardMonitorSpy: KeyboardEventMonitoring {
    var onEvent: ((KeyboardSoundEvent) -> Void)?
    var onInterruption: (() -> Void)?
    var hasPermission = true
    var starts = 0
    var failStart = false
    var isRunning = false
    func requestPermission() {}
    func start() throws { if failStart { throw KeyboardSoundError.eventTap }; starts += 1; isRunning = true }
    func stop() { isRunning = false }
    func resetPressedKeys() {}
}

@MainActor
private final class KeyboardPlayerSpy: KeyboardSoundPlaying {
    var onConfigurationChange: (() -> Void)?
    var previews: [KeyboardSoundPack] = []
    var hits = 0
    var suspends = 0
    var prepares = 0
    var failPrepare = false
    var failPlay = false
    func prepare() throws {
        prepares += 1
        if failPrepare { throw KeyboardSoundError.rendererUnavailable }
    }
    func play(_ event: KeyboardSoundEvent, configuration: KeyboardSoundConfiguration) throws {
        if failPlay { throw KeyboardSoundError.rendererUnavailable }
        hits += 1
    }
    func preview(_ pack: KeyboardSoundPack, configuration: KeyboardSoundConfiguration) throws { previews.append(pack) }
    func setVolume(_ volume: Double) {}
    func silence() {}
    func suspend() { suspends += 1 }
}
