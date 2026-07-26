import AppKit
import Combine
@preconcurrency import ScreenCaptureKit

@MainActor
final class AppCoordinator: ControlGestureMonitorDelegate, ClipboardTextMonitorDelegate {
    private let windowManager: WindowManager
    private let captureService: CaptureService
    private let store: CaptureStore
    private let pillViewModel: PillViewModel
    private let voiceContextService: VoiceContextService
    private let monitor = ControlGestureMonitor()
    private let clipboardMonitor = ClipboardTextMonitor()
    private let codingAgentBridge = CodingAgentBridgeService()
    private let codexHookInstaller = CodexHookInstaller()
    private var claudeCodeHookInstaller: ClaudeCodeHookInstaller?

    private var activeScreen: NSScreen?
    private var activeStroke: Stroke?
    private var isCapturing = false
    private var annotationSessionID: UUID?
    private var annotationVoiceError: String?
    private var annotationVoiceWasRequested = false
    private var transcriptionQueue: Task<Void, Never>?
    private var debugOverlayWorkItems: [DispatchWorkItem] = []
    private var codingAgentIntegrationSettingsCancellable: AnyCancellable?
    private var isCodingAgentBridgeRunning = false
    private var observedCodingAgentProviders: Set<UsageLimitProvider> = []

    init(
        windowManager: WindowManager,
        captureService: CaptureService,
        store: CaptureStore,
        pillViewModel: PillViewModel,
        voiceContextService: VoiceContextService
    ) {
        self.windowManager = windowManager
        self.captureService = captureService
        self.store = store
        self.pillViewModel = pillViewModel
        self.voiceContextService = voiceContextService
    }

    func start() {
        DebugLogger.log("app.start", [
            "bundle": Bundle.main.bundleIdentifier ?? "unknown",
            "executable": Bundle.main.executablePath ?? "unknown",
            "screenPreflight": "\(CGPreflightScreenCaptureAccess())",
            "accessibility": "\(AXIsProcessTrusted())"
        ])
        logScreens()

        pillViewModel.onTestScreenshot = { [weak self] in
            self?.runDebugScreenshotTest()
        }
        pillViewModel.onTestOverlay = { [weak self] in
            self?.runDebugOverlayTest()
        }
        pillViewModel.onWillWritePasteboard = { [weak self] in
            self?.clipboardMonitor.ignoreNextPasteboardWrite()
        }
        pillViewModel.onDeleteHistoryItem = { [weak self] item in
            self?.deleteHistoryItem(item)
        }
        pillViewModel.onWillShowHistory = { [weak self] in
            self?.syncHistoryFromStore()
        }
        pillViewModel.onResolveAgentApproval = { [weak self] approvalID, decision in
            self?.codingAgentBridge.resolve(approvalID, decision: decision)
            self?.windowManager.agentInteractionDidResolve()
        }
        pillViewModel.onResolveAgentQuestion = { [weak self] questionID, answers in
            self?.codingAgentBridge.answer(questionID, answers: answers)
            self?.windowManager.agentInteractionDidResolve()
        }
        pillViewModel.onCodingAgentStateChange = { [weak self] in
            self?.windowManager.codingAgentStateDidChange()
        }

        codingAgentBridge.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleCodingAgentHookEvent(event)
            }
        }
        codingAgentBridge.onApprovalInvalidated = { [weak self] approvalID, reason in
            Task { @MainActor [weak self] in
                self?.pillViewModel.invalidateAgentApproval(approvalID, reason: reason)
                self?.windowManager.agentInteractionDidResolve()
            }
        }
        codingAgentBridge.onQuestionInvalidated = { [weak self] questionID, reason in
            Task { @MainActor [weak self] in
                self?.pillViewModel.invalidateAgentQuestion(questionID, reason: reason)
                self?.windowManager.agentInteractionDidResolve()
            }
        }
        do {
            try codingAgentBridge.start()
            isCodingAgentBridgeRunning = true
        } catch {
            isCodingAgentBridgeRunning = false
            pillViewModel.setCodingAgentIntegrationStatus("Bridge unavailable: \(error.localizedDescription)")
            DebugLogger.log("agents.bridge.start.error", errorFields(error))
        }

        codingAgentIntegrationSettingsCancellable = Publishers.CombineLatest(
            pillViewModel.settings.$codingAgentIntegrationEnabled,
            pillViewModel.settings.$claudeCodeConfigDirectory
        )
            .removeDuplicates { previous, current in
                previous.0 == current.0 && previous.1 == current.1
            }
            .sink { [weak self] integrationSettings in
                let (isEnabled, claudeCodeConfigDirectory) = integrationSettings
                Task { @MainActor [weak self] in
                    self?.configureCodingAgentIntegration(
                        isEnabled: isEnabled,
                        claudeCodeConfigDirectory: claudeCodeConfigDirectory
                    )
                }
            }

        syncHistoryFromStore()
        pillViewModel.clearCaptureIssue()
        pillViewModel.startUsageLimitUpdates()

        windowManager.showPill()

        monitor.delegate = self
        clipboardMonitor.delegate = self
        clipboardMonitor.start()
        do {
            try monitor.start()
        } catch {
            pillViewModel.showCaptureIssue(.inputMonitoring(detail: error.localizedDescription))
        }
    }

    func stop() {
        DebugLogger.log("app.stop")
        if let annotationSessionID {
            voiceContextService.cancelRecording(sessionID: annotationSessionID)
        }
        transcriptionQueue?.cancel()
        transcriptionQueue = nil
        monitor.stop()
        clipboardMonitor.stop()
        pillViewModel.stopUsageLimitUpdates()
        codingAgentIntegrationSettingsCancellable?.cancel()
        codingAgentIntegrationSettingsCancellable = nil
        codingAgentBridge.stop()
        isCodingAgentBridgeRunning = false
    }

    private func handleCodingAgentHookEvent(_ event: CodingAgentHookEvent) {
        guard pillViewModel.settings.codingAgentIntegrationEnabled else {
            if let approvalID = event.approvalID {
                codingAgentBridge.declineToDecide(approvalID)
            }
            if let questionID = event.questionRequestID {
                codingAgentBridge.declineToAnswer(questionID)
            }
            return
        }

        observedCodingAgentProviders.insert(event.provider)
        updateCodingAgentIntegrationStatus()
        let shouldPresentInteraction = pillViewModel.receiveCodingAgentHookEvent(event)
        if shouldPresentInteraction {
            windowManager.presentCodingAgentInteraction()
        } else {
            windowManager.agentInteractionDidResolve()
        }
    }

    private func configureCodingAgentIntegration(
        isEnabled: Bool,
        claudeCodeConfigDirectory: String
    ) {
        let nextClaudeCodeHookInstaller = ClaudeCodeHookInstaller(
            claudeHome: CodingAgentConfiguration.claudeHome(
                configuredDirectory: claudeCodeConfigDirectory
            )
        )
        pillViewModel.refreshUsageLimitsSoon()

        guard isEnabled else {
            disableCodingAgentIntegration(
                nextClaudeCodeHookInstaller: nextClaudeCodeHookInstaller
            )
            return
        }

        do {
            if let claudeCodeHookInstaller,
               claudeCodeHookInstaller.settingsURL.standardizedFileURL
                != nextClaudeCodeHookInstaller.settingsURL.standardizedFileURL,
               claudeCodeHookInstaller.containsAssistHandlers() {
                try claudeCodeHookInstaller.uninstall()
            }
            claudeCodeHookInstaller = nextClaudeCodeHookInstaller

            try codexHookInstaller.install(executableURL: Bundle.main.executableURL)
            try nextClaudeCodeHookInstaller.install(executableURL: Bundle.main.executableURL)
            updateCodingAgentIntegrationStatus()
            DebugLogger.log("agents.integration.enabled")
        } catch {
            pillViewModel.setCodingAgentIntegrationStatus(error.localizedDescription)
            DebugLogger.log("agents.integration.configure.error", errorFields(error))
        }
    }

    private func disableCodingAgentIntegration(
        nextClaudeCodeHookInstaller: ClaudeCodeHookInstaller
    ) {
        codingAgentBridge.declineToDecideAll()
        pillViewModel.clearCodingAgentState()
        observedCodingAgentProviders.removeAll()
        windowManager.agentInteractionDidResolve()

        var uninstallErrors: [String] = []
        func uninstall(_ label: String, _ operation: () throws -> Void) {
            do {
                try operation()
            } catch {
                uninstallErrors.append("\(label): \(error.localizedDescription)")
                DebugLogger.log("agents.integration.uninstall.error", [
                    "provider": label,
                    "message": error.localizedDescription
                ])
            }
        }

        if codexHookInstaller.containsAssistHandlers() {
            uninstall("Codex") {
                try codexHookInstaller.uninstall()
            }
        }
        if let claudeCodeHookInstaller,
           claudeCodeHookInstaller.settingsURL.standardizedFileURL
            != nextClaudeCodeHookInstaller.settingsURL.standardizedFileURL,
           claudeCodeHookInstaller.containsAssistHandlers() {
            uninstall("Claude Code (previous directory)") {
                try claudeCodeHookInstaller.uninstall()
            }
        }
        if nextClaudeCodeHookInstaller.containsAssistHandlers() {
            uninstall("Claude Code") {
                try nextClaudeCodeHookInstaller.uninstall()
            }
        }
        claudeCodeHookInstaller = nextClaudeCodeHookInstaller

        if uninstallErrors.isEmpty {
            pillViewModel.setCodingAgentIntegrationStatus("Not connected")
            DebugLogger.log("agents.integration.disabled")
        } else {
            pillViewModel.setCodingAgentIntegrationStatus(
                "Disconnected. Assist could not remove every hook: \(uninstallErrors.joined(separator: " "))"
            )
        }
    }

    private func updateCodingAgentIntegrationStatus() {
        guard pillViewModel.settings.codingAgentIntegrationEnabled else {
            pillViewModel.setCodingAgentIntegrationStatus("Not connected")
            return
        }

        guard isCodingAgentBridgeRunning else {
            pillViewModel.setCodingAgentIntegrationStatus(
                "Hooks installed, but the local Assist bridge is unavailable."
            )
            return
        }

        let observedCodex = observedCodingAgentProviders.contains(.codex)
        let observedClaudeCode = observedCodingAgentProviders.contains(.claudeCode)
        switch (observedCodex, observedClaudeCode) {
        case (true, true):
            pillViewModel.setCodingAgentIntegrationStatus("Active with Codex and Claude Code")
        case (true, false):
            pillViewModel.setCodingAgentIntegrationStatus(
                "Codex is active. Claude Code hooks are installed and waiting for a session."
            )
        case (false, true):
            pillViewModel.setCodingAgentIntegrationStatus(
                "Claude Code is active. In Codex, open /hooks and trust the Assist hook."
            )
        case (false, false):
            pillViewModel.setCodingAgentIntegrationStatus(
                "Hooks installed. In Codex, open /hooks and trust the Assist hook."
            )
        }
    }

    func clipboardTextMonitor(_ monitor: ClipboardTextMonitor, didCopy text: String) {
        guard !isAssistCapturePathText(text) else {
            DebugLogger.log("clipboard.text.ignored", [
                "characters": "\(text.count)",
                "reason": "assistCapturePath"
            ])
            return
        }

        do {
            let item = try store.save(text: text)
            pillViewModel.insertTextItem(item)
            pillViewModel.statusText = "Copied text"
            pillViewModel.diagnosticMessage = "Captured copied text"
            pillViewModel.showCopyFeedback(badge: "Copied", preview: item.preview)
            DebugLogger.log("clipboard.text.saved", [
                "id": item.id.uuidString,
                "characters": "\(item.text.count)"
            ])
        } catch {
            DebugLogger.log("clipboard.text.save.error", errorFields(error))
        }
    }

    private func isAssistCapturePathText(_ text: String) -> Bool {
        let trimmed = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .replacingOccurrences(of: "\\ ", with: " ")

        guard trimmed.count < 4_096 else { return false }

        let fileURL: URL
        if trimmed.hasPrefix("file://"),
           let url = URL(string: trimmed),
           url.isFileURL {
            fileURL = url
        } else if trimmed.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: trimmed)
        } else {
            return false
        }

        guard Self.captureImageExtensions.contains(fileURL.pathExtension.lowercased()) else {
            return false
        }

        let path = fileURL.standardizedFileURL.path
        return assistCaptureDirectories.contains { directory in
            path == directory || path.hasPrefix(directory + "/")
        }
    }

    private var assistCaptureDirectories: [String] {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var supportDirectoryNames = [AppIdentity.supportDirectoryName]
        if let legacySupportDirectoryName = AppIdentity.legacySupportDirectoryName {
            supportDirectoryNames.append(legacySupportDirectoryName)
        }

        return supportDirectoryNames.map {
            base
                .appendingPathComponent($0, isDirectory: true)
                .appendingPathComponent("Captures", isDirectory: true)
                .standardizedFileURL
                .path
        }
    }

    private static let captureImageExtensions = Set(["png", "jpg", "jpeg", "heic", "tif", "tiff"])

    private func deleteHistoryItem(_ item: ClipboardHistoryItem) {
        do {
            switch item {
            case let .screenshot(capture):
                try store.delete(item: capture)
            case let .text(textClip):
                try store.delete(textItem: textClip)
            }

            pillViewModel.remove(item)
            pillViewModel.statusText = "Deleted"
            pillViewModel.diagnosticMessage = "Deleted item from history"
            DebugLogger.log("history.item.deleted", ["id": item.id.uuidString])
        } catch {
            DebugLogger.log("history.item.delete.error", errorFields(error))
            pillViewModel.statusText = "Delete failed"
            pillViewModel.diagnosticMessage = error.localizedDescription
        }
    }

    private func syncHistoryFromStore() {
        let screenshots = store.loadItems()
        let textClips = visibleTextClips(from: store.loadTextItems())
        let previousIDs = Set(pillViewModel.historyItems.map(\.id))
        let nextIDs = Set((screenshots.map(ClipboardHistoryItem.screenshot) + textClips.map(ClipboardHistoryItem.text)).map(\.id))

        pillViewModel.replaceHistory(screenshots: screenshots, textClips: textClips)

        if previousIDs != nextIDs {
            DebugLogger.log("history.synced", [
                "screenshots": "\(screenshots.count)",
                "textClips": "\(textClips.count)"
            ])
        }
    }

    private func visibleTextClips(from textClips: [TextClipItem]) -> [TextClipItem] {
        var visibleTextClips: [TextClipItem] = []
        var prunedCount = 0

        for textClip in textClips {
            guard isAssistCapturePathText(textClip.text) else {
                visibleTextClips.append(textClip)
                continue
            }

            do {
                try store.delete(textItem: textClip)
                prunedCount += 1
            } catch {
                DebugLogger.log("clipboard.text.prune.error", errorFields(error))
            }
        }

        if prunedCount > 0 {
            DebugLogger.log("clipboard.text.pruned", [
                "count": "\(prunedCount)",
                "reason": "assistCapturePath"
            ])
        }

        return visibleTextClips
    }

    func annotationGestureDidBegin(at globalPoint: CGPoint) {
        guard !isCapturing else { return }

        guard let screen = NSScreen.screen(containing: globalPoint) ?? NSScreen.main else {
            return
        }

        DebugLogger.log("annotation.begin.request", [
            "point": DebugLogger.describe(globalPoint),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        let sessionID = UUID()
        annotationSessionID = sessionID
        annotationVoiceError = nil
        annotationVoiceWasRequested = pillViewModel.settings.voiceContextEnabled
        isCapturing = true
        pillViewModel.isBusy = true
        pillViewModel.statusText = "Annotating..."

        if annotationVoiceWasRequested {
            do {
                try voiceContextService.startRecording(sessionID: sessionID)
                pillViewModel.statusText = "Listening…"
            } catch {
                annotationVoiceError = error.localizedDescription
                DebugLogger.log("voice.recording.start.error", errorFields(error))
            }
        }

        let startPoint = screen.localTopLeftPoint(forGlobalPoint: globalPoint)
        let stroke = Stroke(points: [startPoint], colorHex: "#FF3B30", width: 5)

        activeScreen = screen
        activeStroke = stroke

        windowManager.showOverlay(on: screen, stroke: stroke)
        DebugLogger.log("annotation.overlay.show", [
            "session": sessionID.uuidString,
            "screenFrame": DebugLogger.describe(screen.frame)
        ])
        DebugLogger.log("annotation.begin.ready", [
            "session": sessionID.uuidString,
            "startPoint": DebugLogger.describe(startPoint)
        ])
    }

    func annotationGestureDidMove(to globalPoint: CGPoint) {
        guard isCapturing, let screen = activeScreen, var stroke = activeStroke else { return }

        let point = screen.localTopLeftPoint(forGlobalPoint: globalPoint)
        guard stroke.points.last.map({ $0.distance(to: point) > 1.5 }) ?? true else { return }

        stroke.points.append(point)
        activeStroke = stroke
        windowManager.updateOverlay(stroke: stroke)
        if stroke.points.count % 20 == 0 {
            DebugLogger.log("annotation.move", [
                "points": "\(stroke.points.count)",
                "point": DebugLogger.describe(point)
            ])
        }
    }

    func annotationGestureDidEnd(at globalPoint: CGPoint) {
        guard isCapturing, let screen = activeScreen, var stroke = activeStroke else {
            DebugLogger.log("annotation.end.no-active-stroke", [
                "point": DebugLogger.describe(globalPoint)
            ])
            if let annotationSessionID {
                voiceContextService.cancelRecording(sessionID: annotationSessionID)
            }
            resetCaptureState(reason: "annotation.no-active-stroke")
            return
        }

        let sessionID = annotationSessionID
        let recording = sessionID.flatMap { voiceContextService.stopRecording(sessionID: $0) }
        let voiceError = annotationVoiceError
        let voiceContextWasEnabled = annotationVoiceWasRequested

        let point = screen.localTopLeftPoint(forGlobalPoint: globalPoint)
        if stroke.points.last != point {
            stroke.points.append(point)
        }

        windowManager.hideOverlay()
        DebugLogger.log("annotation.overlay.hide", [
            "reason": "annotation.end",
            "session": annotationSessionID?.uuidString ?? "unknown"
        ])
        pillViewModel.isBusy = true
        pillViewModel.statusText = "Saving capture..."
        DebugLogger.log("annotation.end", [
            "points": "\(stroke.points.count)",
            "point": DebugLogger.describe(globalPoint),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        let sessionLogID = sessionID?.uuidString ?? "unknown"
        Task {
            do {
                DebugLogger.log("annotation.capture.start", ["session": sessionLogID])
                let captured = try await captureService.capture(screen: screen)
                guard self.annotationSessionID == sessionID else {
                    DebugLogger.log("annotation.capture.stale-session", ["session": sessionLogID])
                    return
                }

                DebugLogger.log("annotation.capture.success", [
                    "session": sessionLogID,
                    "displayID": "\(captured.displayID)",
                    "imageSize": "\(captured.image.width)x\(captured.image.height)"
                ])
                DebugLogger.log("annotation.composite.start", [
                    "session": sessionLogID,
                    "points": "\(stroke.points.count)"
                ])
                let finalImage = try captureService.composite(captured: captured, stroke: stroke)
                DebugLogger.log("annotation.composite.success", [
                    "session": sessionLogID,
                    "imageSize": "\(Int(finalImage.size.width))x\(Int(finalImage.size.height))"
                ])
                let context = self.initialContextForAnnotatedCapture(
                    recording: recording,
                    voiceError: voiceError,
                    voiceContextWasEnabled: voiceContextWasEnabled
                )
                if let item = saveCapture(
                    image: finalImage,
                    statusText: "Saving capture...",
                    context: context
                ), let recording {
                    enqueueTranscription(recording, for: item)
                }
                windowManager.restorePillToFront(reason: "annotation.finished")
                resetCaptureState(reason: "annotation.finished")
            } catch {
                guard self.annotationSessionID == sessionID else {
                    DebugLogger.log("annotation.error.stale-session", ["session": sessionLogID])
                    return
                }

                DebugLogger.log("annotation.capture-or-composite.error", errorFields(error))
                handleCaptureError(error)
                windowManager.restorePillToFront(reason: "annotation.error")
                resetCaptureState(reason: "annotation.error")
            }
        }
    }

    func controlOptionScreenshotRequested(at globalPoint: CGPoint) {
        DebugLogger.log("clean-screenshot.shortcut", [
            "point": DebugLogger.describe(globalPoint)
        ])
        windowManager.hideOverlay()
        resetCaptureState(reason: "clean-screenshot.shortcut")
        saveCleanScreenshot(at: globalPoint)
    }

    private func saveCleanScreenshot(at globalPoint: CGPoint) {
        guard let screen = NSScreen.screen(containing: globalPoint) ?? NSScreen.main else {
            return
        }

        pillViewModel.statusText = "Saving screenshot..."
        pillViewModel.isBusy = true
        DebugLogger.log("clean-screenshot.capture.request", [
            "point": DebugLogger.describe(globalPoint),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        Task {
            do {
                let captured = try await captureService.capture(screen: screen)
                let image = captureService.image(from: captured)
                saveCapture(image: image, statusText: "Saving screenshot...", context: .saved)
            } catch {
                DebugLogger.log("clean-screenshot.capture.error", errorFields(error))
                handleCaptureError(error)
            }
        }
    }

    @discardableResult
    private func saveCapture(
        image: NSImage,
        statusText: String,
        context: ScreenshotContext
    ) -> CaptureItem? {
        pillViewModel.statusText = statusText
        pillViewModel.isBusy = true
        DebugLogger.log("capture.save.start", [
            "status": statusText,
            "imageSize": "\(Int(image.size.width))x\(Int(image.size.height))"
        ])

        do {
            pillViewModel.clearCaptureIssue()
            let item = try store.save(image: image, context: context)
            insertOrUpdate(item)
            pillViewModel.diagnosticMessage = "Saved \(URL(fileURLWithPath: item.imagePath).lastPathComponent)"
            DebugLogger.log("capture.save.success", [
                "id": item.id.uuidString,
                "imagePath": item.imagePath
            ])
            DebugLogger.log("capture.saved", [
                "id": item.id.uuidString,
                "imagePath": item.imagePath
            ])
            if let dictation = context.dictation {
                switch dictation.status {
                case .transcribing:
                    pillViewModel.statusText = "Transcribing…"
                    pillViewModel.isBusy = true
                case .failed:
                    pillViewModel.statusText = dictation.errorDetails ?? "Transcription failed"
                    pillViewModel.isBusy = false
                case .ready, .noSpeech:
                    pillViewModel.statusText = "Ready"
                    pillViewModel.isBusy = false
                }
            } else {
                pillViewModel.statusText = "Ready"
                pillViewModel.isBusy = false
            }
            pillViewModel.showCopyFeedback(badge: "Saved", preview: "Screenshot")
            return item
        } catch {
            DebugLogger.log("capture.save.failure", errorFields(error))
            DebugLogger.log("capture.save.error", errorFields(error))
            pillViewModel.statusText = error.localizedDescription
            pillViewModel.isBusy = false
            pillViewModel.showCaptureIssue(.captureFailed(detail: error.localizedDescription))
            return nil
        }
    }

    private func initialContextForAnnotatedCapture(
        recording: VoiceRecording?,
        voiceError: String?,
        voiceContextWasEnabled: Bool
    ) -> ScreenshotContext {
        var context = ScreenshotContext.saved
        guard voiceContextWasEnabled else { return context }

        if let voiceError {
            context.dictation = dictationContext(status: .failed, errorDetails: voiceError)
        } else if recording != nil {
            context.dictation = dictationContext(status: .transcribing)
        } else {
            context.dictation = dictationContext(
                status: .failed,
                errorDetails: "No microphone recording was attached to this annotation."
            )
        }
        return context
    }

    private func enqueueTranscription(_ recording: VoiceRecording, for item: CaptureItem) {
        let previousTask = transcriptionQueue
        transcriptionQueue = Task { [weak self] in
            _ = await previousTask?.result
            guard let self, !Task.isCancelled else { return }

            var updatedItem = item
            do {
                if let transcript = try await voiceContextService.transcribe(recording) {
                    updatedItem.context.dictation = dictationContext(
                        status: .ready,
                        transcript: transcript.text,
                        language: transcript.language
                    )
                } else {
                    updatedItem.context.dictation = dictationContext(status: .noSpeech)
                }
            } catch {
                updatedItem.context.dictation = dictationContext(
                    status: .failed,
                    errorDetails: error.localizedDescription
                )
                DebugLogger.log("voice.transcription.error", errorFields(error).merging([
                    "captureID": item.id.uuidString,
                    "session": recording.sessionID.uuidString
                ]) { current, _ in current })
            }

            guard pillViewModel.items.contains(where: { $0.id == updatedItem.id }) else {
                return
            }
            do {
                try store.update(item: updatedItem)
            } catch {
                DebugLogger.log("capture.context.update.error", errorFields(error).merging([
                    "captureID": item.id.uuidString
                ]) { current, _ in current })
                pillViewModel.diagnosticMessage = error.localizedDescription
                guard !isCapturing,
                      pillViewModel.items.first?.id == updatedItem.id else { return }
                pillViewModel.isBusy = false
                pillViewModel.statusText = "Context save failed"
                return
            }
            pillViewModel.updateScreenshot(updatedItem)

            guard !isCapturing,
                  pillViewModel.items.first?.id == updatedItem.id,
                  let dictation = updatedItem.context.dictation else { return }
            pillViewModel.isBusy = false
            switch dictation.status {
            case .ready:
                pillViewModel.statusText = "Ready"
            case .noSpeech:
                pillViewModel.statusText = "No speech detected"
                pillViewModel.diagnosticMessage = "Screenshot saved. No speech was detected in the microphone recording."
            case .failed:
                pillViewModel.statusText = dictation.errorDetails ?? "Transcription failed"
            case .transcribing:
                pillViewModel.statusText = "Transcribing…"
            }
        }
    }

    private func dictationContext(
        status: DictationStatus,
        transcript: String = "",
        language: String = "en",
        errorDetails: String? = nil
    ) -> DictationContext {
        DictationContext(
            status: status,
            transcript: transcript,
            language: language,
            modelIdentifier: VoiceContextService.modelIdentifier,
            modelRevision: VoiceContextService.modelRevision,
            errorDetails: errorDetails
        )
    }

    private func handleCaptureError(_ error: Error) {
        let hasScreenCaptureAccess = CGPreflightScreenCaptureAccess()
        DebugLogger.log("capture.handle-error", errorFields(error).merging([
            "screenPreflight": "\(hasScreenCaptureAccess)"
        ]) { current, _ in current })

        let nsError = error as NSError
        pillViewModel.clearCaptureIssue()

        if !hasScreenCaptureAccess {
            DebugLogger.log("capture.handle-error.tcc-denied", [
                "description": nsError.localizedDescription
            ])
            pillViewModel.showCaptureIssue(.screenRecording(detail: nsError.localizedDescription))
            pillViewModel.openControls()
            return
        }

        if isScreenCaptureKitUserDeclined(nsError) {
            DebugLogger.log("capture.handle-error.sck-user-declined-with-access", [
                "description": nsError.localizedDescription
            ])
        }

        DebugLogger.log("capture.handle-error.status-only", [
            "description": nsError.localizedDescription
        ])
        pillViewModel.showCaptureIssue(.captureFailed(detail: nsError.localizedDescription))
    }

    private func isScreenCaptureKitUserDeclined(_ error: NSError) -> Bool {
        error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain"
            && error.code == SCStreamError.Code.userDeclined.rawValue
    }

    private func runDebugScreenshotTest() {
        let point = NSEvent.mouseLocation
        DebugLogger.log("debug.screenshot-test.clicked", [
            "point": DebugLogger.describe(point),
            "screenPreflight": "\(CGPreflightScreenCaptureAccess())"
        ])
        saveCleanScreenshot(at: point)
    }

    private func runDebugOverlayTest() {
        cancelDebugOverlayTest()

        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screen(containing: point) ?? NSScreen.main else {
            pillViewModel.diagnosticMessage = "No screen found for overlay test."
            DebugLogger.log("debug.overlay-test.no-screen", ["point": DebugLogger.describe(point)])
            return
        }

        let pointer = screen.localTopLeftPoint(forGlobalPoint: point)
        let radius: CGFloat = 58
        let center = CGPoint(
            x: min(max(pointer.x, radius + 20), screen.frame.width - radius - 20),
            y: min(max(pointer.y, radius + 20), screen.frame.height - radius - 20)
        )
        let start = CGPoint(x: center.x + radius, y: center.y)
        var stroke = Stroke(points: [start], colorHex: "#FF3B30", width: 6)

        pillViewModel.statusText = "Overlay test"
        pillViewModel.isBusy = true
        pillViewModel.diagnosticMessage = "Showing the two-second fluid trail..."
        DebugLogger.log("debug.overlay-test.start", [
            "point": DebugLogger.describe(point),
            "localPoint": DebugLogger.describe(start),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        windowManager.showOverlay(on: screen, stroke: stroke)

        let pointCount = 144
        for index in 1...pointCount {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let angle = CGFloat(index) / CGFloat(pointCount) * .pi * 6
                let nextPoint = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                stroke.points.append(nextPoint)
                self.windowManager.updateOverlay(stroke: stroke)
            }
            debugOverlayWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.025, execute: workItem)
        }

        let hideWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.windowManager.hideOverlay()
            self.pillViewModel.statusText = "Ready"
            self.pillViewModel.isBusy = false
            self.pillViewModel.diagnosticMessage = "Overlay test completed. The live circle should fade while the saved annotation remains complete."
            DebugLogger.log("debug.overlay-test.end", ["points": "\(stroke.points.count)"])
            self.debugOverlayWorkItems.removeAll()
        }
        debugOverlayWorkItems.append(hideWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.8, execute: hideWorkItem)
    }

    private func cancelDebugOverlayTest() {
        for workItem in debugOverlayWorkItems {
            workItem.cancel()
        }
        debugOverlayWorkItems.removeAll()
        windowManager.hideOverlay()
        pillViewModel.isBusy = false
    }

    private func errorFields(_ error: Error) -> [String: String] {
        let nsError = error as NSError
        return [
            "domain": nsError.domain,
            "code": "\(nsError.code)",
            "description": nsError.localizedDescription
        ]
    }

    private func logScreens() {
        for (index, screen) in NSScreen.screens.enumerated() {
            DebugLogger.log("screen.available", [
                "index": "\(index)",
                "frame": DebugLogger.describe(screen.frame),
                "visible": DebugLogger.describe(screen.visibleFrame),
                "scale": "\(screen.backingScaleFactor)"
            ])
        }
    }

    private func insertOrUpdate(_ item: CaptureItem) {
        pillViewModel.replaceScreenshot(item)
    }

    private func resetCaptureState(reason: String) {
        DebugLogger.log("capture.state.reset", [
            "reason": reason,
            "wasCapturing": "\(isCapturing)",
            "hadActiveScreen": "\(activeScreen != nil)",
            "hadActiveStroke": "\(activeStroke != nil)",
            "session": annotationSessionID?.uuidString ?? "none"
        ])
        if let annotationSessionID {
            voiceContextService.cancelRecording(sessionID: annotationSessionID)
        }
        isCapturing = false
        activeScreen = nil
        activeStroke = nil
        annotationSessionID = nil
        annotationVoiceError = nil
        annotationVoiceWasRequested = false
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private extension NSScreen {
    static func screen(containing point: CGPoint) -> NSScreen? {
        screens.first { $0.frame.contains(point) }
    }

    func localTopLeftPoint(forGlobalPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - frame.minX,
            y: frame.maxY - point.y
        )
    }
}
