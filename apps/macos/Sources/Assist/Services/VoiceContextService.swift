@preconcurrency import AVFoundation
import Combine
import Foundation
import WhisperKit

enum VoiceModelState: Equatable {
    case unsupported
    case notInstalled
    case downloading(Double)
    case preparing
    case ready
    case failed(String)

    var isReady: Bool {
        self == .ready
    }
}

enum MicrophoneAccessState: Equatable {
    case notDetermined
    case authorized
    case denied

    var isAuthorized: Bool {
        self == .authorized
    }
}

struct VoiceRecording: Sendable {
    let sessionID: UUID
    let samples: [Float]
}

struct LocalTranscript: Sendable, Equatable {
    let text: String
    let language: String
}

struct VoiceSignalAssessment: Sendable, Equatable {
    let sampleCount: Int
    let duration: TimeInterval
    let rmsEnergy: Float
    let peakAmplitude: Float
    let activeFrameCount: Int
    let hasSpeech: Bool
}

enum VoiceSignalAnalyzer {
    // WhisperKit's default 0.02 RMS threshold rejects normal quiet speech from
    // some built-in Mac microphones. -50 dBFS still clears a typical room-noise
    // floor while allowing softly dictated speech through to Whisper's own
    // no-speech probability check.
    static let energyThreshold: Float = 0.003
    static let minimumActiveFrameCount = 2

    static func assess(_ samples: [Float]) -> VoiceSignalAssessment {
        guard !samples.isEmpty else {
            return VoiceSignalAssessment(
                sampleCount: 0,
                duration: 0,
                rmsEnergy: 0,
                peakAmplitude: 0,
                activeFrameCount: 0,
                hasSpeech: false
            )
        }

        let energy = AudioProcessor.calculateEnergy(of: samples)
        let activeFrames = EnergyVAD(
            frameLength: 0.1,
            frameOverlap: 0.05,
            energyThreshold: energyThreshold
        )
        .voiceActivity(in: samples)
        .filter { $0 }
        .count

        return VoiceSignalAssessment(
            sampleCount: samples.count,
            duration: Double(samples.count) / Double(WhisperKit.sampleRate),
            rmsEnergy: energy.avg,
            peakAmplitude: energy.max,
            activeFrameCount: activeFrames,
            hasSpeech: activeFrames >= minimumActiveFrameCount
        )
    }
}

enum VoiceContextError: LocalizedError {
    case unsupportedHardware
    case modelNotReady
    case microphoneAccessDenied
    case recordingAlreadyActive
    case audioInputFailed(String)
    case modelDownloadFailed(String)
    case modelLoadFailed(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedHardware:
            "Voice context requires an Apple Silicon Mac."
        case .modelNotReady:
            "The Whisper voice model is not installed and ready."
        case .microphoneAccessDenied:
            "Microphone access is not enabled for Assist."
        case .recordingAlreadyActive:
            "A voice recording is already attached to another annotation."
        case let .audioInputFailed(detail):
            "Microphone recording failed: \(detail)"
        case let .modelDownloadFailed(detail):
            "Whisper model download failed: \(detail)"
        case let .modelLoadFailed(detail):
            "Whisper model load failed: \(detail)"
        case let .transcriptionFailed(detail):
            "Local transcription failed: \(detail)"
        }
    }
}

@MainActor
protocol VoiceAudioRecording: AnyObject {
    var audioSamples: ContiguousArray<Float> { get }
    func prepare() throws
    func start(callback: @escaping ([Float]) -> Void) throws
    func pause()
    func stop()
}

@MainActor
private final class WhisperAudioRecorder: VoiceAudioRecording {
    private let bufferStore = LockedAudioBuffer()
    private var audioEngine: AVAudioEngine?
    private var inputFormat: AVAudioFormat?
    private var converter: AVAudioConverter?

    var audioSamples: ContiguousArray<Float> {
        bufferStore.snapshot()
    }

    func prepare() throws {
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceContextError.audioInputFailed("The default input device has no readable audio format.")
        }
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(WhisperKit.sampleRate),
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: format, to: desiredFormat) else {
            throw VoiceContextError.audioInputFailed("Assist could not create the 16 kHz mono audio converter.")
        }

        engine.prepare()
        audioEngine = engine
        inputFormat = format
        self.converter = converter
    }

    func start(callback: @escaping ([Float]) -> Void) throws {
        try prepare()
        guard let audioEngine, let inputFormat, let converter else {
            throw VoiceContextError.audioInputFailed("The prepared audio engine is unavailable.")
        }

        bufferStore.reset(callback: callback)
        let inputNode = audioEngine.inputNode
        let bufferSize = AVAudioFrameCount(max(1, Int(inputFormat.sampleRate * 0.1)))
        inputNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: inputFormat,
            block: VoiceAudioTapBlockFactory.make(
                bufferStore: bufferStore,
                converter: converter
            )
        )

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            bufferStore.finish()
            throw error
        }
    }

    func pause() {
        audioEngine?.pause()
    }

    func stop() {
        guard let audioEngine else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        bufferStore.finish()
        audioEngine.prepare()
    }
}

enum VoiceAudioTapBlockFactory {
    nonisolated static func make(
        bufferStore: LockedAudioBuffer,
        converter: AVAudioConverter
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            do {
                let converted = try AudioProcessor.resampleBuffer(buffer, with: converter)
                let samples = AudioProcessor.convertBufferToArray(buffer: converted)
                bufferStore.append(samples)
            } catch {
                DebugLogger.logFromAnyThread(
                    "voice.recording.convert.error",
                    ["description": error.localizedDescription]
                )
            }
        }
    }
}

final class LockedAudioBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: ContiguousArray<Float> = []
    private var callback: (([Float]) -> Void)?

    func reset(callback: @escaping ([Float]) -> Void) {
        lock.lock()
        samples = []
        self.callback = callback
        lock.unlock()
    }

    func append(_ nextSamples: [Float]) {
        lock.lock()
        samples.append(contentsOf: nextSamples)
        let callback = callback
        lock.unlock()
        callback?(nextSamples)
    }

    func snapshot() -> ContiguousArray<Float> {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    func finish() {
        lock.lock()
        callback = nil
        lock.unlock()
    }
}

@MainActor
final class VoiceContextService: ObservableObject {
    nonisolated static let modelIdentifier = "argmaxinc/whisperkit-coreml/openai_whisper-small.en"
    nonisolated static let modelRevision = "97a5bf9bbc74c7d9c12c755d04dea59e672e3808"
    nonisolated static let modelDownloadSizeDescription = "approximately 487 MB"

    @Published private(set) var modelState: VoiceModelState
    @Published private(set) var microphoneAccessState: MicrophoneAccessState

    private static let modelRepository = "argmaxinc/whisperkit-coreml"
    private static let modelFolderName = "openai_whisper-small.en"
    private static let sampleRate = 16_000
    private static let maximumSampleCount = sampleRate * 90

    private let modelsDirectory: URL
    private let manifestURL: URL
    private let transcriber = WhisperTranscriber()
    private let audioRecorder: any VoiceAudioRecording
    private var activeRecordingSessionID: UUID?
    private var recordedSampleCount = 0
    private var didReachRecordingLimit = false

    init(
        applicationSupportDirectory: URL? = nil,
        audioRecorder: (any VoiceAudioRecording)? = nil,
        modelStateOverride: VoiceModelState? = nil,
        microphoneAccessStateOverride: MicrophoneAccessState? = nil
    ) {
        let supportDirectory = applicationSupportDirectory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
        modelsDirectory = supportDirectory.appendingPathComponent("Models", isDirectory: true)
        manifestURL = modelsDirectory.appendingPathComponent("voice-context-model.json")
        self.audioRecorder = audioRecorder ?? WhisperAudioRecorder()
        microphoneAccessState = microphoneAccessStateOverride ?? Self.currentMicrophoneAccessState()

        #if arch(arm64)
        modelState = modelStateOverride
            ?? (Self.hasInstalledPinnedModel(manifestURL: manifestURL) ? .ready : .notInstalled)
        #else
        modelState = modelStateOverride ?? .unsupported
        #endif

        if modelState.isReady, microphoneAccessState.isAuthorized {
            try? self.audioRecorder.prepare()
        }
    }

    var canRecord: Bool {
        modelState.isReady && microphoneAccessState.isAuthorized
    }

    var modelFolderURL: URL? {
        guard let manifest = try? Self.readManifest(at: manifestURL),
              manifest.identifier == Self.modelIdentifier,
              manifest.revision == Self.modelRevision,
              FileManager.default.fileExists(atPath: manifest.modelFolderPath) else {
            return nil
        }

        return URL(fileURLWithPath: manifest.modelFolderPath, isDirectory: true)
    }

    @discardableResult
    func installModel() async -> Bool {
        #if !arch(arm64)
        modelState = .unsupported
        return false
        #else
        guard case .downloading = modelState else {
            if modelState == .preparing { return false }
            if modelState == .ready { return true }
            return await performModelInstallation()
        }
        return false
        #endif
    }

    @discardableResult
    func requestMicrophoneAccess() async -> Bool {
        let granted = await AudioProcessor.requestRecordPermission()
        microphoneAccessState = granted ? .authorized : .denied
        if granted {
            do {
                try audioRecorder.prepare()
            } catch {
                DebugLogger.log("voice.recording.prepare.error", [
                    "description": error.localizedDescription
                ])
            }
        }
        return granted
    }

    func startRecording(sessionID: UUID) throws {
        guard modelState.isReady else { throw VoiceContextError.modelNotReady }
        guard microphoneAccessState.isAuthorized else { throw VoiceContextError.microphoneAccessDenied }
        guard activeRecordingSessionID == nil else { throw VoiceContextError.recordingAlreadyActive }

        activeRecordingSessionID = sessionID
        recordedSampleCount = 0
        didReachRecordingLimit = false

        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            try audioRecorder.start { [weak self] samples in
                Task { @MainActor [weak self] in
                    self?.didReceiveAudio(samples.count, sessionID: sessionID)
                }
            }
            DebugLogger.log("voice.recording.started", [
                "session": sessionID.uuidString,
                "startupMilliseconds": String(
                    format: "%.1f",
                    (CFAbsoluteTimeGetCurrent() - startTime) * 1_000
                )
            ])
        } catch {
            activeRecordingSessionID = nil
            throw VoiceContextError.audioInputFailed(error.localizedDescription)
        }
    }

    func stopRecording(sessionID: UUID) -> VoiceRecording? {
        guard activeRecordingSessionID == sessionID else { return nil }

        audioRecorder.stop()
        let samples = Array(audioRecorder.audioSamples.prefix(Self.maximumSampleCount))
        DebugLogger.log("voice.recording.stopped", [
            "durationSeconds": String(format: "%.3f", Double(samples.count) / Double(Self.sampleRate)),
            "samples": "\(samples.count)",
            "session": sessionID.uuidString
        ])
        activeRecordingSessionID = nil
        recordedSampleCount = 0
        didReachRecordingLimit = false
        return VoiceRecording(sessionID: sessionID, samples: samples)
    }

    func cancelRecording(sessionID: UUID) {
        guard activeRecordingSessionID == sessionID else { return }
        audioRecorder.stop()
        activeRecordingSessionID = nil
        recordedSampleCount = 0
        didReachRecordingLimit = false
    }

    func transcribe(_ recording: VoiceRecording) async throws -> LocalTranscript? {
        let assessment = VoiceSignalAnalyzer.assess(recording.samples)
        DebugLogger.log("voice.signal.assessed", [
            "activeFrames": "\(assessment.activeFrameCount)",
            "durationSeconds": String(format: "%.3f", assessment.duration),
            "hasSpeech": "\(assessment.hasSpeech)",
            "peak": String(format: "%.6f", assessment.peakAmplitude),
            "rms": String(format: "%.6f", assessment.rmsEnergy),
            "samples": "\(assessment.sampleCount)",
            "session": recording.sessionID.uuidString,
            "threshold": String(format: "%.6f", VoiceSignalAnalyzer.energyThreshold)
        ])
        guard assessment.hasSpeech else { return nil }

        do {
            let transcript = try await transcriber.transcribe(
                samples: recording.samples,
                modelFolder: modelFolderURL
            )
            DebugLogger.log("voice.transcription.ready", [
                "characters": "\(transcript.text.count)",
                "language": transcript.language,
                "session": recording.sessionID.uuidString
            ])
            return transcript
        } catch let error as VoiceContextError {
            throw error
        } catch {
            throw VoiceContextError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func performModelInstallation() async -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: modelsDirectory,
                withIntermediateDirectories: true
            )
            modelState = .downloading(0)
            let modelFolder = try await transcriber.downloadModel(
                downloadBase: modelsDirectory,
                repository: Self.modelRepository,
                folderName: Self.modelFolderName,
                revision: Self.modelRevision
            ) { [weak self] fractionCompleted in
                Task { @MainActor [weak self] in
                    self?.modelState = .downloading(fractionCompleted)
                }
            }

            modelState = .preparing
            try await transcriber.prepareModel(at: modelFolder)
            try Self.writeManifest(
                ModelManifest(
                    identifier: Self.modelIdentifier,
                    revision: Self.modelRevision,
                    modelFolderPath: modelFolder.path
                ),
                to: manifestURL
            )
            modelState = .ready
            return true
        } catch {
            let detail = error.localizedDescription
            modelState = .failed(detail)
            DebugLogger.log("voice.model.setup.error", ["description": detail])
            return false
        }
    }

    private func didReceiveAudio(_ sampleCount: Int, sessionID: UUID) {
        guard activeRecordingSessionID == sessionID, !didReachRecordingLimit else { return }
        recordedSampleCount += sampleCount
        guard recordedSampleCount >= Self.maximumSampleCount else { return }

        didReachRecordingLimit = true
        audioRecorder.pause()
        DebugLogger.log("voice.recording.limit", ["session": sessionID.uuidString])
    }

    private static func currentMicrophoneAccessState() -> MicrophoneAccessState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            .authorized
        case .notDetermined:
            .notDetermined
        case .denied, .restricted:
            .denied
        @unknown default:
            .denied
        }
    }

    private static func hasInstalledPinnedModel(manifestURL: URL) -> Bool {
        guard let manifest = try? readManifest(at: manifestURL),
              manifest.identifier == modelIdentifier,
              manifest.revision == modelRevision else {
            return false
        }

        return FileManager.default.fileExists(atPath: manifest.modelFolderPath)
    }

    private static func readManifest(at url: URL) throws -> ModelManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ModelManifest.self, from: data)
    }

    private static func writeManifest(_ manifest: ModelManifest, to url: URL) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: url, options: .atomic)
    }
}

private struct ModelManifest: Codable {
    let identifier: String
    let revision: String
    let modelFolderPath: String
}

private actor WhisperTranscriber {
    private var whisperKit: WhisperKit?
    private var loadedModelFolder: URL?

    func downloadModel(
        downloadBase: URL,
        repository: String,
        folderName: String,
        revision: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let hub = HubApiWrapper(downloadBase: downloadBase)
        let repo = HubApiWrapper.Repo(id: repository)
        let pattern = "\(folderName)/*"
        let filenames = try await hub.getFilenames(
            from: repo,
            revision: revision,
            matching: [pattern]
        )
        guard !filenames.isEmpty else {
            throw VoiceContextError.modelDownloadFailed(
                "No files were found for \(folderName) at revision \(revision)."
            )
        }

        let repositoryFolder = try await hub.snapshot(
            from: repo,
            revision: revision,
            matching: [pattern]
        ) { downloadProgress in
            progress(downloadProgress.fractionCompleted)
        }
        let modelFolder = repositoryFolder.appendingPathComponent(folderName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: modelFolder.path) else {
            throw VoiceContextError.modelDownloadFailed(
                "The downloaded model folder was not found at \(modelFolder.path)."
            )
        }

        return modelFolder
    }

    func prepareModel(at modelFolder: URL) async throws {
        do {
            try await loadModel(at: modelFolder)
        } catch {
            throw VoiceContextError.modelLoadFailed(error.localizedDescription)
        }
    }

    func transcribe(samples: [Float], modelFolder: URL?) async throws -> LocalTranscript {
        guard let modelFolder else { throw VoiceContextError.modelNotReady }

        if whisperKit == nil || loadedModelFolder != modelFolder {
            do {
                try await loadModel(at: modelFolder)
            } catch {
                throw VoiceContextError.modelLoadFailed(error.localizedDescription)
            }
        }
        guard let whisperKit else { throw VoiceContextError.modelNotReady }

        let options = DecodingOptions(
            language: "en",
            temperature: 0,
            usePrefillPrompt: true,
            withoutTimestamps: true,
            wordTimestamps: false
        )
        do {
            let results = try await whisperKit.transcribe(
                audioArray: samples,
                decodeOptions: options
            )
            let text = results.map(\.text).joined()
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw VoiceContextError.transcriptionFailed(
                    "Whisper returned an empty transcript for audio that contained speech."
                )
            }
            return LocalTranscript(text: text, language: results.first?.language ?? "en")
        } catch {
            throw VoiceContextError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func loadModel(at modelFolder: URL) async throws {
        let configuration = WhisperKitConfig(
            modelFolder: modelFolder.path,
            verbose: false,
            prewarm: true,
            load: true,
            download: false
        )
        whisperKit = try await WhisperKit(configuration)
        loadedModelFolder = modelFolder
    }
}
