import AppKit
import Combine

@MainActor
final class PillViewModel: ObservableObject {
    @Published var latestItem: CaptureItem?
    @Published var items: [CaptureItem] = []
    @Published private(set) var thumbnailImages: [UUID: NSImage] = [:]
    @Published var statusText = "Hold Ctrl / Ctrl+Opt"
    @Published var isExpanded = false
    @Published var isExpandedContentVisible = false
    @Published var isCollapsedContentVisible = true
    @Published var isBusy = false
    @Published var diagnosticMessage: String?

    var onTestScreenshot: (() -> Void)?
    var onTestOverlay: (() -> Void)?

    func clearCaptureIssue() {
        if statusText == "Capture failed" || statusText == "Capture fallback" {
            statusText = "Hold Ctrl / Ctrl+Opt"
        }
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

    func copyLatestContext() {
        guard let latestItem else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(latestItem.agentMarkdown, forType: .string)
    }

    func copyLatestImage() {
        guard let latestItem,
              let image = NSImage(contentsOfFile: latestItem.imagePath) else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    func cacheThumbnails(for items: [CaptureItem]) {
        let validIDs = Set(items.map(\.id))
        var nextImages = thumbnailImages.filter { validIDs.contains($0.key) }

        for item in items.prefix(40) where nextImages[item.id] == nil {
            if let image = NSImage(contentsOfFile: item.thumbnailPath) {
                nextImages[item.id] = image
            }
        }

        thumbnailImages = nextImages
    }

    func thumbnail(for item: CaptureItem) -> NSImage? {
        thumbnailImages[item.id]
    }
}

private extension CaptureItem {
    var agentMarkdown: String {
        """
        # AI Clipboard Capture

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
