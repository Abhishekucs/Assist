@preconcurrency import AVFoundation
import Foundation
import KeyboardAudioRender

@MainActor
protocol KeyboardSoundPlaying: AnyObject {
    var onConfigurationChange: (() -> Void)? { get set }
    func prepare() throws
    func play(_ event: KeyboardSoundEvent, configuration: KeyboardSoundConfiguration) throws
    func preview(_ pack: KeyboardSoundPack, configuration: KeyboardSoundConfiguration) throws
    func setVolume(_ volume: Double)
    func silence()
    func suspend()
}

/// Immutable samples and an atomic command queue shared with the render thread.
/// Destruction happens only after AVAudioEngine has stopped and released its node.
final class KeyboardSoundRenderStorage: @unchecked Sendable {
    let pointer: OpaquePointer

    init() throws {
        guard let pointer = keyboard_audio_create(UInt32(KeyboardSoundPack.allCases.count * 12)) else {
            throw KeyboardSoundError.rendererUnavailable
        }
        self.pointer = pointer
    }

    deinit { keyboard_audio_destroy(pointer) }

    func loadSamples() throws {
        let root = Bundle.main.url(forResource: "Sounds", withExtension: nil)
            ?? Bundle.module.url(forResource: "Sounds", withExtension: nil)
        guard let root else { throw KeyboardSoundError.missingSamples }
        for pack in KeyboardSoundPack.allCases {
            for phase in ["down", "up"] {
                for key in 0..<6 {
                    let url = root.appendingPathComponent(pack.rawValue).appendingPathComponent("\(phase)-\(key).wav")
                    let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
                    guard file.processingFormat.sampleRate == 48_000,
                          file.processingFormat.channelCount == 1,
                          file.length > 1, file.length <= 48_000,
                          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                        frameCapacity: AVAudioFrameCount(file.length)) else {
                        throw KeyboardSoundError.missingSamples
                    }
                    try file.read(into: buffer)
                    guard let samples = buffer.floatChannelData?[0] else { throw KeyboardSoundError.missingSamples }
                    let index = pack.sampleOffset + (phase == "down" ? 0 : 6) + key
                    guard keyboard_audio_set_sample(pointer, UInt32(index), samples, buffer.frameLength) else {
                        throw KeyboardSoundError.rendererUnavailable
                    }
                }
            }
        }
    }
}

@MainActor
final class KeyboardSoundEngine: KeyboardSoundPlaying {
    var onConfigurationChange: (() -> Void)?
    private var engine: AVAudioEngine?
    private var storage: KeyboardSoundRenderStorage?
    private var configurationObserver: NSObjectProtocol?
    private var idleTimer: Timer?
    private var variation = 0
    private var volume: Double = 0.35

    func prepare() throws {
        guard engine == nil else { return }
        let storage = try KeyboardSoundRenderStorage()
        try storage.loadSamples()
        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let node = AVAudioSourceNode(format: format) { @Sendable [storage] _, _, frames, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count == 2, let left = buffers[0].mData, let right = buffers[1].mData else {
                return kAudio_ParamError
            }
            keyboard_audio_render(storage.pointer, left.assumingMemoryBound(to: Float.self),
                                  right.assumingMemoryBound(to: Float.self), frames)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.prepare()
        self.storage = storage
        self.engine = engine
        keyboard_audio_set_volume(storage.pointer, Float(volume))
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.suspend()
                self?.onConfigurationChange?()
            }
        }
    }

    func play(_ event: KeyboardSoundEvent, configuration: KeyboardSoundConfiguration) throws {
        try enqueue(event, configuration: configuration, delayFrames: 0)
    }

    private func enqueue(_ event: KeyboardSoundEvent, configuration: KeyboardSoundConfiguration, delayFrames: UInt32) throws {
        try prepare()
        guard let engine, let storage else { throw KeyboardSoundError.rendererUnavailable }
        setVolume(configuration.volume)
        if !engine.isRunning { try engine.start() }
        variation = (variation + 1) % 3
        _ = keyboard_audio_enqueue_after(
            storage.pointer, UInt32(event.sampleIndex(pack: configuration.pack, variation: variation)),
            Float.random(in: 0.92...1.04), configuration.stereo ? event.pan : 0,
            Float.random(in: 0.985...1.015), delayFrames
        )
        scheduleIdleSuspension()
    }

    func preview(_ pack: KeyboardSoundPack, configuration: KeyboardSoundConfiguration) throws {
        // Schedule a complete tap on the audio timeline, with release 80 ms
        // after press. A reset invalidates both hits, including a pending release.
        var preview = configuration
        preview.pack = pack
        try play(KeyboardSoundEvent(keyCode: 4, phase: .down), configuration: preview)
        try enqueue(KeyboardSoundEvent(keyCode: 4, phase: .up), configuration: preview, delayFrames: 3_840)
    }

    func setVolume(_ volume: Double) {
        self.volume = volume.isFinite ? min(1, max(0, volume)) : 0
        if let storage { keyboard_audio_set_volume(storage.pointer, Float(self.volume)) }
    }

    func silence() {
        if let storage {
            keyboard_audio_set_volume(storage.pointer, 0)
            keyboard_audio_reset(storage.pointer)
        }
    }

    func suspend() {
        idleTimer?.invalidate()
        idleTimer = nil
        silence()
        engine?.stop()
    }

    private func scheduleIdleSuspension() {
        idleTimer?.invalidate()
        // Product inactivity policy: keep audio warm during typing, release the
        // output device after eight seconds of silence. This is not a retry.
        let timer = Timer(timeInterval: 8, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.suspend() }
        }
        idleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
    }
}
