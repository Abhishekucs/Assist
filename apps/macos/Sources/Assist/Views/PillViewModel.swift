import AppKit
import Combine

@MainActor
final class PillViewModel: ObservableObject {
    let settings: PillSettings

    @Published var latestItem: CaptureItem?
    @Published var items: [CaptureItem] = []
    @Published var textItems: [TextClipItem] = []
    @Published var selectedHistoryItem: ClipboardHistoryItem?
    @Published private(set) var thumbnailImages: [UUID: NSImage] = [:]
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
    @Published private(set) var usageLimitSnapshots: [UsageLimitProvider: UsageLimitSnapshot] = PillViewModel.emptyUsageLimitSnapshots()
    @Published private(set) var isRefreshingUsageLimits = false
    @Published private(set) var activeCodexTasks: [CodexTask] = []
    @Published private(set) var isRefreshingCodexTasks = false

    private var copyFeedbackDismissWorkItem: DispatchWorkItem?
    private var copyFeedbackClearWorkItem: DispatchWorkItem?
    private let updateService = AppUpdateService()
    private var usageLimitRefreshTask: Task<Void, Never>?
    private var usageLimitOnDemandTask: Task<Void, Never>?
    private var codexTaskRefreshTask: Task<Void, Never>?
    private var codexTaskOnDemandTask: Task<Void, Never>?

    private static let copyFeedbackClearDelay: TimeInterval = 0.22
    private static let usageLimitRefreshIntervalNanoseconds: UInt64 = 180_000_000_000
    private static let codexTaskRefreshIntervalNanoseconds: UInt64 = 8_000_000_000

    var onTestScreenshot: (() -> Void)?
    var onTestOverlay: (() -> Void)?
    var onOpenControls: (() -> Void)?
    var onWillWritePasteboard: (() -> Void)?
    var onDeleteHistoryItem: ((ClipboardHistoryItem) -> Void)?
    var onWillShowHistory: (() -> Void)?

    init(settings: PillSettings) {
        self.settings = settings
    }

    deinit {
        usageLimitRefreshTask?.cancel()
        usageLimitOnDemandTask?.cancel()
        codexTaskRefreshTask?.cancel()
        codexTaskOnDemandTask?.cancel()
    }

    func startUsageLimitUpdates() {
        guard usageLimitRefreshTask == nil else { return }

        usageLimitRefreshTask = Task { [weak self] in
            await self?.refreshUsageLimits()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.usageLimitRefreshIntervalNanoseconds)
                await self?.refreshUsageLimits()
            }
        }
    }

    func stopUsageLimitUpdates() {
        usageLimitRefreshTask?.cancel()
        usageLimitRefreshTask = nil
        usageLimitOnDemandTask?.cancel()
        usageLimitOnDemandTask = nil
    }

    func refreshUsageLimitsSoon() {
        usageLimitOnDemandTask?.cancel()
        usageLimitOnDemandTask = Task { [weak self] in
            await self?.refreshUsageLimits()
        }
    }

    private func refreshUsageLimits() async {
        guard !isRefreshingUsageLimits else { return }

        isRefreshingUsageLimits = true
        let snapshots = await UsageLimitService.loadSnapshots()
        usageLimitSnapshots = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.provider, $0) }
        )
        isRefreshingUsageLimits = false
    }

    func startCodexTaskUpdates() {
        guard codexTaskRefreshTask == nil else { return }

        codexTaskRefreshTask = Task { [weak self] in
            await self?.refreshCodexTasks()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: Self.codexTaskRefreshIntervalNanoseconds)
                } catch {
                    return
                }
                await self?.refreshCodexTasks()
            }
        }
    }

    func stopCodexTaskUpdates() {
        codexTaskRefreshTask?.cancel()
        codexTaskRefreshTask = nil
        codexTaskOnDemandTask?.cancel()
        codexTaskOnDemandTask = nil
    }

    func refreshCodexTasksSoon() {
        codexTaskOnDemandTask?.cancel()
        codexTaskOnDemandTask = Task { [weak self] in
            await self?.refreshCodexTasks()
        }
    }

    private func refreshCodexTasks() async {
        guard !isRefreshingCodexTasks else { return }

        isRefreshingCodexTasks = true
        activeCodexTasks = await CodexTaskService.loadActiveTasks()
        isRefreshingCodexTasks = false
    }

    func showCopyFeedback(badge: String, preview: String) {
        copyFeedbackDismissWorkItem?.cancel()
        copyFeedbackClearWorkItem?.cancel()

        let collapsedPreview = preview
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let feedback = CopyFeedback(
            id: UUID(),
            badge: badge,
            preview: String(collapsedPreview.prefix(80))
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: dismissWorkItem)
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
        refreshUsageLimitsSoon()
        refreshCodexTasksSoon()
    }

    func openCodexTask(_ task: CodexTask) {
        guard let url = URL(string: "codex://threads/\(task.id)") else {
            statusText = "Open failed"
            diagnosticMessage = "Could not create a Codex task link."
            return
        }

        if NSWorkspace.shared.open(url) {
            statusText = "Opened Codex"
            diagnosticMessage = "Opened \(task.workspaceName) in Codex"
        } else {
            statusText = "Codex not found"
            diagnosticMessage = "Install the Codex app to open this task."
        }
    }

    var orderedUsageLimitSnapshots: [UsageLimitSnapshot] {
        UsageLimitProvider.allCases.map {
            usageLimitSnapshots[$0] ?? .unavailable(provider: $0)
        }
    }

    private static func emptyUsageLimitSnapshots() -> [UsageLimitProvider: UsageLimitSnapshot] {
        Dictionary(
            uniqueKeysWithValues: UsageLimitProvider.allCases.map {
                ($0, UsageLimitSnapshot.unavailable(provider: $0))
            }
        )
    }

    func copyLatestImage() {
        guard case let .screenshot(item) = selectedItem,
              copyImageItem(item) else { return }
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

    func insertTextItem(_ item: TextClipItem) {
        var nextItems = textItems.filter { $0.id != item.id }
        nextItems.insert(item, at: 0)
        textItems = Array(nextItems.prefix(80))
        selectedHistoryItem = .text(item)
    }

    func cacheThumbnails(for items: [CaptureItem]) {
        let validIDs = Set(items.map(\.id))
        var nextImages = thumbnailImages.filter { validIDs.contains($0.key) }

        for item in items.prefix(40) where nextImages[item.id] == nil {
            if let image = warmedImage(at: item.thumbnailPath) {
                nextImages[item.id] = image
            }
        }

        thumbnailImages = nextImages
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

    private func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
