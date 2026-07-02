import AppKit
import Combine

@MainActor
final class PillViewModel: ObservableObject {
    let settings: PillSettings

    @Published var latestItem: CaptureItem?
    @Published var items: [CaptureItem] = []
    @Published var textItems: [TextClipItem] = []
    @Published var selectedHistoryItem: ClipboardHistoryItem?
    @Published var selectedFileIDs: Set<UUID> = []
    @Published private(set) var thumbnailImages: [UUID: NSImage] = [:]
    @Published var statusText = "Hold Ctrl / Ctrl+Opt"
    @Published var isExpanded = false
    @Published var isExpandedContentVisible = false
    @Published var isCollapsedContentVisible = true
    @Published var isBusy = false
    @Published var diagnosticMessage: String?
    @Published var captureIssue: CaptureIssue?

    var onTestScreenshot: (() -> Void)?
    var onTestOverlay: (() -> Void)?
    var onOpenControls: (() -> Void)?
    var onWillWritePasteboard: (() -> Void)?
    var onDeleteHistoryItem: ((ClipboardHistoryItem) -> Void)?

    init(settings: PillSettings) {
        self.settings = settings
    }

    func clearCaptureIssue() {
        if statusText == "Capture failed" || statusText == "Capture fallback" {
            statusText = "Hold Ctrl / Ctrl+Opt"
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

    func openDebugLog() {
        DebugLogger.openLog()
    }

    func perform(_ action: CaptureIssueAction) {
        switch action {
        case .openScreenRecordingSettings:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .openAccessibilitySettings:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .openInputMonitoringSettings:
            openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        case .openDebugLog:
            openDebugLog()
        }
    }

    func openControls() {
        onOpenControls?()
    }

    func copyLatestContext() {
        guard let selectedItem else { return }

        let pasteboard = NSPasteboard.general
        onWillWritePasteboard?()
        pasteboard.clearContents()
        pasteboard.setString(selectedItem.copyPayload, forType: .string)

        if case .text = selectedItem {
            statusText = "Copied text"
        }
    }

    func copyLatestImage() {
        guard case let .screenshot(item) = selectedItem,
              let image = NSImage(contentsOfFile: item.imagePath) else {
            return
        }

        onWillWritePasteboard?()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    func copySelectedScreenshotFiles() {
        let urls = selectedScreenshotFileURLs
        guard !urls.isEmpty else {
            statusText = "No files"
            diagnosticMessage = "No selected screenshot files were found."
            return
        }

        onWillWritePasteboard?()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didWrite = pasteboard.writeObjects(urls.map { $0 as NSURL })

        if didWrite {
            let suffix = urls.count == 1 ? "file" : "files"
            statusText = "Copied \(urls.count) \(suffix)"
            diagnosticMessage = "Copied \(urls.count) screenshot \(suffix) to the clipboard."
        } else {
            statusText = "Copy failed"
            diagnosticMessage = "macOS refused to write the selected files to the clipboard."
        }
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

    var selectedFileCount: Int {
        selectedScreenshotFileURLs.count
    }

    var canCopySelectedFiles: Bool {
        selectedFileCount > 0
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

    func selectScreenshot(_ item: CaptureItem, extendingFileSelection: Bool) {
        selectedHistoryItem = .screenshot(item)
        latestItem = item

        if extendingFileSelection {
            if selectedFileIDs.contains(item.id) {
                selectedFileIDs.remove(item.id)
            } else {
                selectedFileIDs.insert(item.id)
            }
        } else {
            selectedFileIDs = [item.id]
        }
    }

    func copyTextItem(_ item: TextClipItem) {
        select(.text(item))
        selectedFileIDs.removeAll()
        onWillWritePasteboard?()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        statusText = "Copied text"
        diagnosticMessage = "Copied previous text"
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
            selectedFileIDs.remove(capture.id)
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

    func replaceScreenshot(_ item: CaptureItem) {
        captureIssue = nil
        var nextItems = items.filter { $0.id != item.id }
        nextItems.insert(item, at: 0)
        items = nextItems
        latestItem = item
        selectedHistoryItem = .screenshot(item)
        selectedFileIDs = [item.id]
        cacheThumbnails(for: nextItems)
    }

    func insertTextItem(_ item: TextClipItem) {
        var nextItems = textItems.filter { $0.id != item.id }
        nextItems.insert(item, at: 0)
        textItems = Array(nextItems.prefix(80))
        selectedHistoryItem = .text(item)
        selectedFileIDs.removeAll()
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

    private var selectedScreenshotFileURLs: [URL] {
        historyItems.compactMap { historyItem in
            guard case let .screenshot(item) = historyItem,
                  selectedFileIDs.contains(item.id) else {
                return nil
            }

            let url = URL(fileURLWithPath: item.imagePath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    private func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension CaptureItem {
    var agentMarkdown: String {
        """
        # Assist Capture

        Image: \(imagePath)

        Summary:
        \(context.summary)

        Visible text:
        \(context.visibleText.map { "- \($0)" }.joined(separator: "\n"))

        Agent instructions:
        \(context.agentInstructions.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}

private extension TextClipItem {
    var agentMarkdown: String {
        """
        # Assist Text Clip

        Copied at: \(createdAt)

        Text:
        \(text)
        """
    }
}

private extension ClipboardHistoryItem {
    var copyPayload: String {
        switch self {
        case let .screenshot(item):
            item.agentMarkdown
        case let .text(item):
            item.text
        }
    }
}
