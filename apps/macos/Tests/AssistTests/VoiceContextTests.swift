import AppKit
@preconcurrency import AVFoundation
import XCTest
@testable import Assist

final class VoiceContextTests: XCTestCase {
    func testLegacyScreenshotContextDecodesWithoutDictation() throws {
        let json = Data(
            """
            {
              "summary": "Screenshot saved.",
              "visibleText": [],
              "appsDetected": [],
              "uiElements": [],
              "entities": [],
              "sensitiveDataWarnings": []
            }
            """.utf8
        )

        let context = try JSONDecoder().decode(ScreenshotContext.self, from: json)

        XCTAssertNil(context.dictation)
        XCTAssertEqual(context.summary, "Screenshot saved.")
    }

    func testExistingTranscriptionErrorIsNotWrappedTwice() {
        let original = VoiceContextError.transcriptionFailed(
            "Whisper returned an empty transcript for audio that contained speech."
        )

        let normalized = VoiceContextError.transcriptionError(from: original)

        XCTAssertEqual(
            normalized.localizedDescription,
            "Local transcription failed: Whisper returned an empty transcript for audio that contained speech."
        )
    }

    @MainActor
    func testRecordingCannotAttachToAnotherAnnotationSession() throws {
        let recorder = VoiceAudioRecorderSpy()
        let service = VoiceContextService(
            audioRecorder: recorder,
            modelStateOverride: .ready,
            microphoneAccessStateOverride: .authorized
        )
        let firstSession = UUID()
        let laterSession = UUID()

        try service.startRecording(sessionID: firstSession)
        recorder.append([0.1, 0.2, 0.3])

        XCTAssertNil(service.stopRecording(sessionID: laterSession))
        XCTAssertEqual(recorder.stopCount, 0)

        let recording = try XCTUnwrap(service.stopRecording(sessionID: firstSession))
        XCTAssertEqual(recording.sessionID, firstSession)
        XCTAssertEqual(recording.samples, [0.1, 0.2, 0.3])
        XCTAssertTrue(recorder.audioSamples.isEmpty)
        XCTAssertEqual(recorder.stopCount, 1)

        try service.startRecording(sessionID: laterSession)
        recorder.append([0.9])
        let laterRecording = try XCTUnwrap(service.stopRecording(sessionID: laterSession))
        XCTAssertEqual(laterRecording.samples, [0.9])
    }

    @MainActor
    func testRecordingIsCappedAtNinetySeconds() async throws {
        let recorder = VoiceAudioRecorderSpy()
        let service = VoiceContextService(
            audioRecorder: recorder,
            modelStateOverride: .ready,
            microphoneAccessStateOverride: .authorized
        )
        let sessionID = UUID()
        try service.startRecording(sessionID: sessionID)

        recorder.append(Array(repeating: 0.1, count: 1_440_100))
        await Task.yield()

        XCTAssertEqual(recorder.pauseCount, 1)
        let recording = try XCTUnwrap(service.stopRecording(sessionID: sessionID))
        XCTAssertEqual(recording.samples.count, 1_440_000)
        XCTAssertTrue(recorder.audioSamples.isEmpty)
    }

    @MainActor
    func testCancellingRecordingClearsBufferedAudio() throws {
        let recorder = VoiceAudioRecorderSpy()
        let service = VoiceContextService(
            audioRecorder: recorder,
            modelStateOverride: .ready,
            microphoneAccessStateOverride: .authorized
        )
        let sessionID = UUID()
        try service.startRecording(sessionID: sessionID)
        recorder.append([0.1, 0.2, 0.3])

        service.cancelRecording(sessionID: sessionID)

        XCTAssertTrue(recorder.audioSamples.isEmpty)
        XCTAssertEqual(recorder.stopCount, 1)
    }

    @MainActor
    func testPreparationFailureKeepsVoiceContextUnavailable() throws {
        let recorder = VoiceAudioRecorderSpy()
        recorder.prepareError = VoiceRecorderTestError.noInputDevice

        let service = VoiceContextService(
            audioRecorder: recorder,
            modelStateOverride: .ready,
            microphoneAccessStateOverride: .authorized
        )

        XCTAssertFalse(service.canRecord)
        XCTAssertFalse(service.prepareAudioInput())
        XCTAssertEqual(
            service.audioInputError,
            "Microphone recording failed: No test audio input device."
        )
        XCTAssertThrowsError(try service.startRecording(sessionID: UUID())) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Microphone recording failed: No test audio input device."
            )
        }
    }

    @MainActor
    func testRecordingStartFailureInvalidatesAudioReadinessUntilRetry() throws {
        let recorder = VoiceAudioRecorderSpy()
        let service = VoiceContextService(
            audioRecorder: recorder,
            modelStateOverride: .ready,
            microphoneAccessStateOverride: .authorized
        )
        recorder.startError = VoiceRecorderTestError.noInputDevice

        XCTAssertThrowsError(try service.startRecording(sessionID: UUID())) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Microphone recording failed: No test audio input device."
            )
        }
        XCTAssertFalse(service.canRecord)
        XCTAssertEqual(service.audioInputState, .failed("No test audio input device."))
        XCTAssertEqual(
            service.audioInputError,
            "Microphone recording failed: No test audio input device."
        )

        recorder.startError = nil
        XCTAssertTrue(service.prepareAudioInput())
        XCTAssertTrue(service.canRecord)
    }

    @MainActor
    func testModelProgressIsRejectedAfterInstallationLeavesDownloadingState() {
        let installationID = UUID()

        XCTAssertTrue(
            VoiceContextService.shouldAcceptModelDownloadProgress(
                activeInstallationID: installationID,
                callbackInstallationID: installationID,
                modelState: .downloading(0.5)
            )
        )

        for terminalState in [
            VoiceModelState.preparing,
            .ready,
            .failed("Download failed.")
        ] {
            XCTAssertFalse(
                VoiceContextService.shouldAcceptModelDownloadProgress(
                    activeInstallationID: nil,
                    callbackInstallationID: installationID,
                    modelState: terminalState
                )
            )
        }

        XCTAssertFalse(
            VoiceContextService.shouldAcceptModelDownloadProgress(
                activeInstallationID: UUID(),
                callbackInstallationID: installationID,
                modelState: .downloading(0)
            )
        )
    }

    func testQuietSpeechLevelPassesEnergyVAD() {
        let quietSpeech = Array(repeating: Float(0.006), count: 4_800)

        let assessment = VoiceSignalAnalyzer.assess(quietSpeech)

        XCTAssertTrue(assessment.hasSpeech)
        XCTAssertGreaterThanOrEqual(
            assessment.activeFrameCount,
            VoiceSignalAnalyzer.minimumActiveFrameCount
        )
    }

    func testRoomNoiseLevelDoesNotPassEnergyVAD() {
        let roomNoise = Array(repeating: Float(0.0005), count: 16_000)

        let assessment = VoiceSignalAnalyzer.assess(roomNoise)

        XCTAssertFalse(assessment.hasSpeech)
        XCTAssertEqual(assessment.activeFrameCount, 0)
    }

    func testSingleTransientDoesNotCountAsSpeech() {
        let transient = Array(repeating: Float(0.02), count: 1_600)
            + Array(repeating: Float(0), count: 3_200)

        let assessment = VoiceSignalAnalyzer.assess(transient)

        XCTAssertFalse(assessment.hasSpeech)
        XCTAssertLessThan(
            assessment.activeFrameCount,
            VoiceSignalAnalyzer.minimumActiveFrameCount
        )
    }

    func testAudioTapBlockCanRunOffMainActor() throws {
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )
        )
        let converter = try XCTUnwrap(AVAudioConverter(from: format, to: format))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_600))
        buffer.frameLength = 1_600
        for index in 0..<1_600 {
            buffer.floatChannelData?[0][index] = 0.01
        }

        let receivedSamples = expectation(description: "Audio tap forwarded samples")
        let sampleStore = LockedAudioBuffer()
        sampleStore.reset { samples in
            XCTAssertFalse(samples.isEmpty)
            receivedSamples.fulfill()
        }
        let tapBlock = VoiceAudioTapBlockFactory.make(
            bufferStore: sampleStore,
            converter: converter
        )
        let sendableTapBlock = UncheckedSendable(value: tapBlock)

        DispatchQueue(label: "AssistTests.AudioTap").async {
            sendableTapBlock.value(buffer, AVAudioTime(sampleTime: 0, atRate: 16_000))
        }

        wait(for: [receivedSamples], timeout: 2)
        XCTAssertFalse(sampleStore.snapshot().isEmpty)
    }

    @MainActor
    func testSilenceSkipsModelLoadingAndReturnsNoTranscript() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistVoiceModelTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let modelFolder = directory.appendingPathComponent("empty-model", isDirectory: true)
        let modelsDirectory = directory.appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let manifest = """
        {
          "identifier": "\(VoiceContextService.modelIdentifier)",
          "revision": "\(VoiceContextService.modelRevision)",
          "modelFolderPath": "\(modelFolder.path)"
        }
        """
        try Data(manifest.utf8).write(
            to: modelsDirectory.appendingPathComponent("voice-context-model.json")
        )
        let service = VoiceContextService(applicationSupportDirectory: directory)

        let result = try await service.transcribe(
            VoiceRecording(sessionID: UUID(), samples: Array(repeating: 0, count: 16_000))
        )

        XCTAssertNil(result)
    }

    @MainActor
    func testContextPasteboardContainsExactMarkdownAndImageRepresentations() throws {
        let fixture = try makeCaptureFixture(transcript: "Fix the selected layout bug.")
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let contextFileURL = try XCTUnwrap(fixture.item.contextFileURL)
        let persistedMarkdown = CaptureContextMarkdown.render(item: fixture.item)
            + "\n\n<!-- exact persisted context -->"
        try Data(persistedMarkdown.utf8).write(to: contextFileURL, options: .atomic)

        try ContextPasteboardWriter(pasteboard: pasteboard).write(fixture.item)

        let items = try XCTUnwrap(pasteboard.pasteboardItems)
        XCTAssertEqual(items.count, 2)
        let expectedMarkdown = String(decoding: try Data(contentsOf: contextFileURL), as: UTF8.self)
        XCTAssertEqual(items[0].string(forType: .string), expectedMarkdown)
        XCTAssertEqual(items[1].data(forType: .png), fixture.pngData)
        XCTAssertNotNil(items[1].data(forType: .tiff))
        XCTAssertEqual(
            items[1].string(forType: .fileURL),
            URL(fileURLWithPath: fixture.item.imagePath).absoluteString
        )
    }

    @MainActor
    func testContextMarkdownOnlyPasteboardCopiesExactSavedFile() throws {
        let fixture = try makeCaptureFixture(transcript: "Refactor the selected function.")
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let contextFileURL = try XCTUnwrap(fixture.item.contextFileURL)
        let exactMarkdown = CaptureContextMarkdown.render(item: fixture.item)
            + "\n\n<!-- preserved byte-for-byte -->"
        try Data(exactMarkdown.utf8).write(to: contextFileURL, options: .atomic)

        try ContextPasteboardWriter(pasteboard: pasteboard).writeMarkdownOnly(fixture.item)

        let items = try XCTUnwrap(pasteboard.pasteboardItems)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].string(forType: .string), exactMarkdown)
        XCTAssertNil(items[0].data(forType: .png))
        XCTAssertNil(items[0].string(forType: .fileURL))
    }

    @MainActor
    func testContextMarkdownOnlyCopyIsIgnoredByClipboardHistoryMonitor() throws {
        let fixture = try makeCaptureFixture(transcript: "Explain this selected warning.")
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let monitor = ClipboardTextMonitor(pasteboard: pasteboard)
        let delegate = ClipboardDelegateSpy()
        monitor.delegate = delegate
        monitor.start()
        defer { monitor.stop() }

        try ContextPasteboardWriter(pasteboard: pasteboard).writeMarkdownOnly(fixture.item) {
            monitor.ignoreNextPasteboardWrite()
        }
        monitor.pollPasteboard()

        XCTAssertEqual(delegate.receivedTexts, [])
    }

    @MainActor
    func testGeneratedMarkdownIsIgnoredByClipboardHistoryMonitor() throws {
        let fixture = try makeCaptureFixture(transcript: "Explain this compiler error.")
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let monitor = ClipboardTextMonitor(pasteboard: pasteboard)
        let delegate = ClipboardDelegateSpy()
        monitor.delegate = delegate
        monitor.start()
        defer { monitor.stop() }

        try ContextPasteboardWriter(pasteboard: pasteboard).write(fixture.item) {
            monitor.ignoreNextPasteboardWrite()
        }
        monitor.pollPasteboard()

        XCTAssertEqual(delegate.receivedTexts, [])
    }

    @MainActor
    func testPendingContextCannotBeCopied() throws {
        let fixture = try makeCaptureFixture(transcript: "This must not be copied yet.")
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        var pendingItem = fixture.item
        pendingItem.context.dictation?.status = .transcribing
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))

        XCTAssertThrowsError(
            try ContextPasteboardWriter(pasteboard: pasteboard).write(pendingItem)
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                ContextPasteboardError.contextNotReady.localizedDescription
            )
        }
        XCTAssertTrue(pasteboard.pasteboardItems?.isEmpty ?? true)
    }

    @MainActor
    func testNewCaptureContextButtonIsVisibleAndOnlyPendingIsDisabled() throws {
        let fixture = try makeCaptureFixture(transcript: "Inspect this capture.")
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let suiteName = "AssistTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = VoiceContextService(
            applicationSupportDirectory: fixture.directory,
            modelStateOverride: .ready,
            microphoneAccessStateOverride: .authorized
        )
        let viewModel = PillViewModel(
            settings: PillSettings(defaults: defaults),
            voiceContextService: service
        )

        var item = fixture.item
        item.context.dictation?.status = .transcribing
        viewModel.replaceScreenshot(item)
        XCTAssertTrue(viewModel.showsCopySelectedContext)
        XCTAssertFalse(viewModel.canCopySelectedContext)
        XCTAssertFalse(viewModel.canCopyContextMarkdown(item))
        XCTAssertEqual(
            viewModel.contextPreview(for: item),
            "Inspect this capture."
        )

        item.context.dictation?.status = .noSpeech
        item.context.dictation?.transcript = ""
        try Data(CaptureContextMarkdown.render(item: item).utf8)
            .write(to: XCTUnwrap(item.contextFileURL), options: .atomic)
        viewModel.replaceScreenshot(item)
        XCTAssertTrue(viewModel.showsCopySelectedContext)
        XCTAssertTrue(viewModel.canCopySelectedContext)
        XCTAssertTrue(viewModel.canCopyContextMarkdown(item))
        XCTAssertEqual(
            viewModel.contextPreview(for: item),
            "No speech was detected for this capture."
        )

        item.context.dictation = nil
        viewModel.replaceScreenshot(item)
        XCTAssertTrue(viewModel.showsCopySelectedContext)
        XCTAssertTrue(viewModel.canCopySelectedContext)
    }

    @MainActor
    private func makeCaptureFixture(transcript: String) throws -> (
        directory: URL,
        item: CaptureItem,
        pngData: Data
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID()
        let captureDirectory = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: false)
        let imageURL = captureDirectory.appendingPathComponent("screenshot.png")

        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 2,
                pixelsHigh: 2,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        bitmap.setColor(NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1), atX: 0, y: 0)
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: imageURL)

        let dictation = DictationContext(
            status: .ready,
            transcript: transcript,
            language: "en",
            modelIdentifier: VoiceContextService.modelIdentifier,
            modelRevision: VoiceContextService.modelRevision,
            errorDetails: nil
        )
        var context = ScreenshotContext.saved
        context.dictation = dictation
        let item = CaptureItem(
            id: id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            imagePath: imageURL.path,
            thumbnailPath: captureDirectory.appendingPathComponent("thumbnail.png").path,
            context: context
        )
        let contextFileURL = try XCTUnwrap(item.contextFileURL)
        try Data(CaptureContextMarkdown.render(item: item).utf8)
            .write(to: contextFileURL, options: .atomic)
        return (directory, item, pngData)
    }
}

private struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
}

@MainActor
private final class VoiceAudioRecorderSpy: VoiceAudioRecording {
    private(set) var audioSamples: ContiguousArray<Float> = []
    private(set) var pauseCount = 0
    private(set) var stopCount = 0
    var prepareError: Error?
    var startError: Error?
    private var callback: (([Float]) -> Void)?

    func prepare() throws {
        if let prepareError {
            throw prepareError
        }
    }

    func start(callback: @escaping ([Float]) -> Void) throws {
        if let startError {
            throw startError
        }
        audioSamples = []
        self.callback = callback
    }

    func append(_ samples: [Float]) {
        audioSamples.append(contentsOf: samples)
        callback?(samples)
    }

    func pause() {
        pauseCount += 1
    }

    func stop() {
        stopCount += 1
        callback = nil
    }

    func takeSamples() -> ContiguousArray<Float> {
        let capturedSamples = audioSamples
        audioSamples = []
        return capturedSamples
    }
}

private enum VoiceRecorderTestError: LocalizedError {
    case noInputDevice

    var errorDescription: String? {
        "No test audio input device."
    }
}

@MainActor
private final class ClipboardDelegateSpy: ClipboardTextMonitorDelegate {
    private(set) var receivedTexts: [String] = []

    func clipboardTextMonitor(_ monitor: ClipboardTextMonitor, didCopy text: String) {
        receivedTexts.append(text)
    }
}
