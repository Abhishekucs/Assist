import AppKit
import Combine

@MainActor
final class PillViewModel: ObservableObject {
    let settings: PillSettings
    let voiceContextService: VoiceContextService

    @Published var latestItem: CaptureItem?
    @Published var items: [CaptureItem] = []
    @Published var textItems: [TextClipItem] = []
    @Published var selectedHistoryItem: ClipboardHistoryItem?
    @Published private(set) var thumbnailImages: [UUID: NSImage] = [:]
    @Published private(set) var captureContextMarkdown: [UUID: String] = [:]
    @Published var statusText = "Hold Opt / Ctrl+Opt"
    @Published var isExpanded = false
    @Published var isExpandedContentVisible = false
    @Published var isCollapsedContentVisible = true
    @Published var isBusy = false
    @Published var diagnosticMessage: String?
    @Published var captureIssue: CaptureIssue?
    @Published var copyFeedback: CopyFeedback?
    @Published var isCopyFeedbackVisible = false
    @Published var isCheckingForUpdates = false
    @Published var updateStatusText: String?

    private var copyFeedbackDismissWorkItem: DispatchWorkItem?
    private var copyFeedbackClearWorkItem: DispatchWorkItem?
    private let updateService = AppUpdateService()

    private static let copyFeedbackClearDelay: TimeInterval = 0.22
    private static let copyFeedbackDisplayDuration: TimeInterval = 1.6

    var onTestScreenshot: (() -> Void)?
    var onTestOverlay: (() -> Void)?
    var onOpenControls: (() -> Void)?
    var onWillWritePasteboard: (() -> Void)?
    var onDeleteHistoryItem: ((ClipboardHistoryItem) -> Void)?
    var onWillShowHistory: (() -> Void)?
    private var isAwaitingMicrophoneSettings = false

    init(settings: PillSettings, voiceContextService: VoiceContextService) {
        self.settings = settings
        self.voiceContextService = voiceContextService
    }

    func showCopyFeedback(badge: String, preview: String, kind: CopyFeedback.Kind = .success) {
        copyFeedbackDismissWorkItem?.cancel()
        copyFeedbackClearWorkItem?.cancel()

        let collapsedPreview = preview
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let feedback = CopyFeedback(
            id: UUID(),
            badge: badge,
            preview: String(collapsedPreview.prefix(80)),
            kind: kind
        )
        copyFeedback = feedback
        isCopyFeedbackVisible = true

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.copyFeedback?.id == feedback.id else { return }
            self.isCopyFeedbackVisible = false

            let clearWorkItem = DispatchWorkItem { [weak self] in
                guard let self, self.copyFeedback?.id == feedback.id else { return }
                self.copyFeedback = nil
            }
            self.copyFeedbackClearWorkItem = clearWorkItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.copyFeedbackClearDelay,
                execute: clearWorkItem
            )
        }
        copyFeedbackDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.copyFeedbackDisplayDuration,
            execute: dismissWorkItem
        )
    }

    func clearCaptureIssue() {
        if statusText == "Capture failed" || statusText == "Capture fallback" {
            statusText = "Hold Opt / Ctrl+Opt"
        }

        captureIssue = nil
    }

    func showCaptureIssue(_ issue: CaptureIssue) {
        captureIssue = issue
        diagnosticMessage = issue.detail
        statusText = issue.title
        isBusy = false
    }

    func testScreenshot() {
        diagnosticMessage = "Running clean screenshot test..."
        onTestScreenshot?()
    }

    func testOverlay() {
        diagnosticMessage = "Running overlay test..."
        onTestOverlay?()
    }

    func requestScreenRecordingPermission() {
        if CGPreflightScreenCaptureAccess() {
            diagnosticMessage = "Screen recording permission is already enabled."
            statusText = "Ready"
            clearCaptureIssue()
            return
        }

        diagnosticMessage = "Requesting screen recording permission..."
        let requestResult = CGRequestScreenCaptureAccess()
        let postflight = CGPreflightScreenCaptureAccess()

        DebugLogger.log("screen-recording.request.result", [
            "bundle": Bundle.main.bundleIdentifier ?? "unknown",
            "executable": Bundle.main.executablePath ?? "unknown",
            "requestResult": "\(requestResult)",
            "postflight": "\(postflight)"
        ])

        if postflight {
            diagnosticMessage = "Screen recording permission is enabled. Quit and reopen Assist if capture still fails."
            statusText = "Ready"
            clearCaptureIssue()
        } else {
            // macOS shows the screen-recording prompt at most once per app
            // session; a silent denial means this session already used it.
            let detail = requestResult
                ? "Turn on \(AppIdentity.name), then quit and reopen \(AppIdentity.name)."
                : "macOS did not show a prompt. Quit and reopen \(AppIdentity.name), then try again. If \(AppIdentity.name) is missing from the list, click + and select \(Bundle.main.bundlePath)."
            diagnosticMessage = detail
            showCaptureIssue(.screenRecordingNeedsSettings(detail: detail))
        }
    }

    func perform(_ action: CaptureIssueAction) {
        switch action {
        case .requestScreenRecordingPermission:
            requestScreenRecordingPermission()
        case .openScreenRecordingSettings:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .openAccessibilitySettings:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .openInputMonitoringSettings:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
    }

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true
        updateStatusText = "Checking for updates..."

        Task {
            do {
                let outcome = try await updateService.checkAndInstallIfAvailable()
                switch outcome {
                case let .upToDate(version):
                    updateStatusText = "Assist is up to date. Current version: v\(version)."
                    isCheckingForUpdates = false
                case let .installStarted(version):
                    updateStatusText = "Installing v\(version). Assist will relaunch automatically."
                }
            } catch {
                updateStatusText = error.localizedDescription
                isCheckingForUpdates = false
            }
        }
    }

    func openControls() {
        onWillShowHistory?()
        onOpenControls?()
    }

    func willShowHistory() {
        onWillShowHistory?()
    }

    func copyLatestImage() {
        guard case let .screenshot(item) = selectedItem,
              copyImageItem(item) else { return }
    }

    func copyLatestContext() {
        guard case let .screenshot(item) = selectedItem else { return }

        do {
            try ContextPasteboardWriter().write(item) { [weak self] in
                self?.onWillWritePasteboard?()
            }
            statusText = "Copied context + image"
            diagnosticMessage = "Copied the saved Markdown context and screenshot. Attachment support depends on the destination."
            showCopyFeedback(badge: "Copied", preview: "Context + image")
            DebugLogger.log("clipboard.context.copy", [
                "id": item.id.uuidString,
                "success": "true"
            ])
        } catch {
            statusText = "Copy failed"
            diagnosticMessage = error.localizedDescription
            DebugLogger.log("clipboard.context.copy", [
                "id": item.id.uuidString,
                "success": "false",
                "description": error.localizedDescription
            ])
        }
    }

    func copyContextMarkdown(_ item: CaptureItem) {
        selectScreenshot(item)

        do {
            try ContextPasteboardWriter().writeMarkdownOnly(item) { [weak self] in
                self?.onWillWritePasteboard?()
            }
            statusText = "Copied context.md"
            diagnosticMessage = "Copied the exact saved Markdown context."
            showCopyFeedback(badge: "Copied", preview: "context.md")
            DebugLogger.log("clipboard.context-markdown.copy", [
                "id": item.id.uuidString,
                "success": "true"
            ])
        } catch {
            statusText = "Copy failed"
            diagnosticMessage = error.localizedDescription
            DebugLogger.log("clipboard.context-markdown.copy", [
                "id": item.id.uuidString,
                "success": "false",
                "description": error.localizedDescription
            ])
        }
    }

    func contextPreview(for item: CaptureItem) -> String {
        guard let markdown = captureContextMarkdown[item.id] else {
            return item.contextFileURL == nil
                ? "Legacy capture — no context.md file"
                : "context.md is unavailable"
        }

        return CaptureContextMarkdown.preview(from: markdown)
    }

    func canCopyContextMarkdown(_ item: CaptureItem) -> Bool {
        item.contextFileURL != nil
            && item.context.dictation?.status != .transcribing
            && captureContextMarkdown[item.id] != nil
    }

    var historyItems: [ClipboardHistoryItem] {
        (items.map(ClipboardHistoryItem.screenshot) + textItems.map(ClipboardHistoryItem.text))
            .sorted { $0.createdAt > $1.createdAt }
    }

    var selectedItem: ClipboardHistoryItem? {
        if let selectedHistoryItem,
           historyItems.contains(selectedHistoryItem) {
            return selectedHistoryItem
        }

        return historyItems.first
    }

    var canCopySelectedImage: Bool {
        if case .screenshot = selectedItem {
            return true
        }

        return false
    }

    var showsCopySelectedContext: Bool {
        guard case let .screenshot(item) = selectedItem else { return false }

        if item.contextFileURL != nil {
            return true
        }

        guard let dictation = item.context.dictation else { return false }
        return dictation.status == .ready && !dictation.transcript.isEmpty
    }

    var canCopySelectedContext: Bool {
        guard case let .screenshot(item) = selectedItem else { return false }

        if item.contextFileURL != nil {
            return item.context.dictation?.status != .transcribing
        }

        guard let dictation = item.context.dictation else { return false }
        return dictation.status == .ready && !dictation.transcript.isEmpty
    }

    var canRevealSelectedScreenshot: Bool {
        if case .screenshot = selectedItem {
            return true
        }

        return false
    }

    func select(_ item: ClipboardHistoryItem) {
        selectedHistoryItem = item

        if case let .screenshot(capture) = item {
            latestItem = capture
        }
    }

    func selectScreenshot(_ item: CaptureItem) {
        selectedHistoryItem = .screenshot(item)
        latestItem = item
    }

    @discardableResult
    func copyImageItem(_ item: CaptureItem) -> Bool {
        selectedHistoryItem = .screenshot(item)
        latestItem = item

        guard let image = NSImage(contentsOfFile: item.imagePath) else {
            statusText = "Copy failed"
            diagnosticMessage = "Screenshot file could not be loaded."
            return false
        }

        onWillWritePasteboard?()
        NSPasteboard.general.clearContents()
        let didCopy = NSPasteboard.general.writeObjects([image])

        if didCopy {
            statusText = "Copied image"
            diagnosticMessage = "Copied screenshot image"
            showCopyFeedback(badge: "Copied", preview: "Screenshot image")
        } else {
            statusText = "Copy failed"
            diagnosticMessage = "macOS rejected the screenshot pasteboard write."
        }

        DebugLogger.log("clipboard.image.copy", [
            "id": item.id.uuidString,
            "success": "\(didCopy)"
        ])

        return didCopy
    }

    func copyTextItem(_ item: TextClipItem) {
        select(.text(item))
        onWillWritePasteboard?()
        NSPasteboard.general.clearContents()
        let didCopy = NSPasteboard.general.setString(item.text, forType: .string)

        if didCopy {
            statusText = "Copied text"
            diagnosticMessage = "Copied previous text"
            showCopyFeedback(badge: "Copied", preview: item.preview)
        } else {
            statusText = "Copy failed"
            diagnosticMessage = "macOS rejected the text pasteboard write."
        }

        DebugLogger.log("clipboard.text.copy", [
            "id": item.id.uuidString,
            "success": "\(didCopy)"
        ])
    }

    func revealSelectedScreenshotInFinder() {
        guard case let .screenshot(item) = selectedItem else { return }

        let imageURL = URL(fileURLWithPath: item.imagePath)
        let directoryURL = imageURL.deletingLastPathComponent()

        if FileManager.default.fileExists(atPath: imageURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([imageURL])
            statusText = "Opened screenshot"
            diagnosticMessage = "Opened screenshot in Finder"
            return
        }

        if FileManager.default.fileExists(atPath: directoryURL.path) {
            NSWorkspace.shared.open(directoryURL)
            statusText = "Opened folder"
            diagnosticMessage = "Screenshot file was missing; opened the capture folder."
            return
        }

        statusText = "Open failed"
        diagnosticMessage = "Screenshot folder not found."
    }

    func delete(_ item: ClipboardHistoryItem) {
        onDeleteHistoryItem?(item)
    }

    func remove(_ item: ClipboardHistoryItem) {
        switch item {
        case let .screenshot(capture):
            items.removeAll { $0.id == capture.id }
            thumbnailImages.removeValue(forKey: capture.id)
            captureContextMarkdown.removeValue(forKey: capture.id)
            if latestItem?.id == capture.id {
                latestItem = items.first
            }
        case let .text(textClip):
            textItems.removeAll { $0.id == textClip.id }
        }

        if selectedHistoryItem?.id == item.id {
            selectedHistoryItem = historyItems.first
        }

        if case let .screenshot(capture) = selectedHistoryItem {
            latestItem = capture
        } else if let latestItem, !items.contains(where: { $0.id == latestItem.id }) {
            self.latestItem = items.first
        }
    }

    func replaceHistory(screenshots: [CaptureItem], textClips: [TextClipItem]) {
        items = screenshots
        textItems = textClips

        if let selectedHistoryItem,
           !historyItems.contains(selectedHistoryItem) {
            self.selectedHistoryItem = historyItems.first
        } else if selectedHistoryItem == nil {
            selectedHistoryItem = historyItems.first
        }

        if let latestItem,
           !screenshots.contains(where: { $0.id == latestItem.id }) {
            self.latestItem = screenshots.first
        } else if latestItem == nil {
            latestItem = screenshots.first
        }

        cacheThumbnails(for: screenshots)
    }

    func replaceScreenshot(_ item: CaptureItem) {
        captureIssue = nil
        var nextItems = items.filter { $0.id != item.id }
        nextItems.insert(item, at: 0)
        items = nextItems
        latestItem = item
        selectedHistoryItem = .screenshot(item)
        cacheThumbnails(for: nextItems)
    }

    func updateScreenshot(_ item: CaptureItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item

        if latestItem?.id == item.id {
            latestItem = item
        }
        if selectedHistoryItem?.id == item.id {
            selectedHistoryItem = .screenshot(item)
        }
        cacheContextMarkdown(for: item)
    }

    func refreshScreenshotPixels(for item: CaptureItem) {
        var nextImages = thumbnailImages
        nextImages.removeValue(forKey: item.id)
        if let image = warmedImage(at: item.thumbnailPath) {
            nextImages[item.id] = image
        }
        thumbnailImages = nextImages

        if latestItem?.id == item.id {
            latestItem = item
        }
        if selectedHistoryItem?.id == item.id {
            selectedHistoryItem = .screenshot(item)
        }
    }

    func setUpVoiceContext() {
        Task { [weak self] in
            guard let self else { return }
            if voiceContextService.modelState == .ready,
               voiceContextService.microphoneAccessState == .denied {
                if voiceContextService.refreshMicrophoneAccessState() {
                    settings.voiceContextEnabled = true
                    diagnosticMessage = "Voice context is ready. Speech stays local and audio is never saved."
                    return
                }

                if voiceContextService.microphoneAccessState == .authorized {
                    settings.voiceContextEnabled = false
                    diagnosticMessage = voiceContextService.audioInputError
                        ?? "Assist could not prepare the microphone input."
                    return
                }

                let url = URL(
                    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                )!
                isAwaitingMicrophoneSettings = true
                NSWorkspace.shared.open(url)
                diagnosticMessage = "Opened Microphone privacy settings."
                return
            }

            let installed = await voiceContextService.installModel()
            guard installed else {
                settings.voiceContextEnabled = false
                return
            }

            let microphoneAuthorized = await voiceContextService.requestMicrophoneAccess()
            settings.voiceContextEnabled = microphoneAuthorized
            if microphoneAuthorized {
                diagnosticMessage = "Voice context is ready. Speech stays local and audio is never saved."
            } else {
                diagnosticMessage = voiceContextService.audioInputError
                    ?? "The model is installed, but microphone access was denied."
            }
        }
    }

    func applicationDidBecomeActive() {
        guard isAwaitingMicrophoneSettings else { return }
        isAwaitingMicrophoneSettings = false

        let microphoneAuthorized = voiceContextService.refreshMicrophoneAccessState()
        settings.voiceContextEnabled = microphoneAuthorized
        diagnosticMessage = microphoneAuthorized
            ? "Voice context is ready. Speech stays local and audio is never saved."
            : voiceContextService.audioInputError ?? "Microphone access is still denied."
    }

    func insertTextItem(_ item: TextClipItem) {
        var nextItems = textItems.filter { $0.id != item.id }
        nextItems.insert(item, at: 0)
        textItems = Array(nextItems.prefix(80))
        selectedHistoryItem = .text(item)
    }

    func cacheThumbnails(for items: [CaptureItem]) {
        let validIDs = Set(items.map(\.id))
        var nextImages = thumbnailImages.filter { validIDs.contains($0.key) }
        var nextMarkdown: [UUID: String] = [:]

        for item in items.prefix(40) where nextImages[item.id] == nil {
            if let image = warmedImage(at: item.thumbnailPath) {
                nextImages[item.id] = image
            }
        }

        for item in items.prefix(40) {
            if let markdown = readContextMarkdown(for: item) {
                nextMarkdown[item.id] = markdown
            }
        }

        thumbnailImages = nextImages
        captureContextMarkdown = nextMarkdown
    }

    func thumbnail(for item: CaptureItem) -> NSImage? {
        thumbnailImages[item.id]
    }

    private func warmedImage(at path: String) -> NSImage? {
        guard let image = NSImage(contentsOfFile: path) else { return nil }

        image.cacheMode = .always
        var proposedRect = CGRect(origin: .zero, size: image.size)
        _ = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)

        return image
    }

    private func cacheContextMarkdown(for item: CaptureItem) {
        if let markdown = readContextMarkdown(for: item) {
            captureContextMarkdown[item.id] = markdown
        } else {
            captureContextMarkdown.removeValue(forKey: item.id)
        }
    }

    private func readContextMarkdown(for item: CaptureItem) -> String? {
        guard let contextFileURL = item.contextFileURL else { return nil }
        return try? String(contentsOf: contextFileURL, encoding: .utf8)
    }

    private func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
