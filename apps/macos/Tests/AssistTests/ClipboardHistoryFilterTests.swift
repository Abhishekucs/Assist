import AppKit
import XCTest
@testable import Assist

final class ClipboardHistoryFilterTests: XCTestCase {
    func testFiltersStayInTheRequestedDisplayOrder() {
        XCTAssertEqual(ClipboardHistoryFilter.allCases, [.all, .text, .images])
        XCTAssertEqual(ClipboardHistoryFilter.allCases.map(\.title), ["All", "Text", "Images"])
    }

    func testFiltersIncludeOnlyTheirMatchingHistoryType() {
        let screenshot = ClipboardHistoryItem.screenshot(
            CaptureItem(
                id: UUID(),
                createdAt: Date(),
                imagePath: "/tmp/screenshot.png",
                thumbnailPath: "/tmp/thumbnail.png",
                context: .saved
            )
        )
        let text = ClipboardHistoryItem.text(
            TextClipItem(id: UUID(), createdAt: Date(), text: "Copied text")
        )

        XCTAssertTrue(ClipboardHistoryFilter.all.includes(screenshot))
        XCTAssertTrue(ClipboardHistoryFilter.all.includes(text))
        XCTAssertTrue(ClipboardHistoryFilter.images.includes(screenshot))
        XCTAssertFalse(ClipboardHistoryFilter.images.includes(text))
        XCTAssertTrue(ClipboardHistoryFilter.text.includes(text))
        XCTAssertFalse(ClipboardHistoryFilter.text.includes(screenshot))
    }

    func testLibraryFiltersSeparateLinksFromTextWithoutChangingTheOriginalClip() {
        let text = TextClipItem(id: UUID(), createdAt: Date(), text: "  Keep the spaces  ")
        let link = TextClipItem(id: UUID(), createdAt: Date(), text: "https://example.com/path?q=1")
        let invalid = TextClipItem(id: UUID(), createdAt: Date(), text: "https://")
        let screenshot = ClipboardHistoryItem.screenshot(
            CaptureItem(id: UUID(), createdAt: Date(), imagePath: "image.png", thumbnailPath: "thumb.png", context: .saved)
        )

        XCTAssertNil(text.linkURL)
        XCTAssertNil(invalid.linkURL)
        XCTAssertEqual(link.linkURL?.absoluteString, link.text)
        XCTAssertEqual(text.text, "  Keep the spaces  ")
        XCTAssertEqual(LibraryContentFilter.allCases, [.all, .text, .images, .links])
        XCTAssertTrue(LibraryContentFilter.text.includes(.text(text)))
        XCTAssertTrue(LibraryContentFilter.text.includes(.text(invalid)))
        XCTAssertFalse(LibraryContentFilter.text.includes(.text(link)))
        XCTAssertTrue(LibraryContentFilter.links.includes(.text(link)))
        XCTAssertFalse(LibraryContentFilter.links.includes(.text(text)))
        XCTAssertTrue(LibraryContentFilter.images.includes(screenshot))
        XCTAssertFalse(LibraryContentFilter.links.includes(screenshot))
        XCTAssertTrue(LibraryContentFilter.all.includes(screenshot))
        XCTAssertTrue(LibraryContentFilter.all.includes(.text(link)))
    }
}

@MainActor
final class ClipboardContentMonitorTests: XCTestCase {
    func testURLOnlyPasteboardAndLongTextAreCapturedWithoutTruncation() {
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let monitor = ClipboardTextMonitor(pasteboard: pasteboard)
        let delegate = ContentSpy()
        monitor.delegate = delegate
        monitor.start()
        defer { monitor.stop() }

        let link = NSPasteboardItem()
        link.setString("https://example.com/path", forType: .URL)
        let initialChangeCount = pasteboard.changeCount
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([link]))
        XCTAssertNotEqual(pasteboard.changeCount, initialChangeCount)
        XCTAssertEqual(pasteboard.string(forType: .URL), "https://example.com/path")
        monitor.pollPasteboard()
        XCTAssertEqual(delegate.texts, ["https://example.com/path"])

        let original = "  " + String(repeating: "x", count: 50_001) + "  "
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString(original, forType: .string))
        monitor.pollPasteboard()

        XCTAssertEqual(delegate.texts, ["https://example.com/path", original])
    }

    func testImagePasteboardIsCapturedAndOwnImageWriteIsIgnored() throws {
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let monitor = ClipboardTextMonitor(pasteboard: pasteboard)
        let delegate = ContentSpy()
        monitor.delegate = delegate
        monitor.start()
        defer { monitor.stop() }
        let image = try makeImage()

        let initialChangeCount = pasteboard.changeCount
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([image]))
        XCTAssertNotEqual(pasteboard.changeCount, initialChangeCount)
        XCTAssertNotNil(NSImage(pasteboard: pasteboard))
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
        monitor.pollPasteboard()
        XCTAssertEqual(delegate.images.count, 1)
        XCTAssertEqual(delegate.images.first?.size, image.size)

        monitor.ignoreNextPasteboardWrite()
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([image]))
        monitor.pollPasteboard()
        XCTAssertEqual(delegate.images.count, 1)
        XCTAssertTrue(delegate.texts.isEmpty)
    }

    private func makeImage() throws -> NSImage {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ))
        for y in 0..<2 {
            for x in 0..<2 {
                bitmap.setColor(NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1), atX: x, y: y)
            }
        }
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.addRepresentation(bitmap)
        return image
    }

    private final class ContentSpy: ClipboardTextMonitorDelegate {
        var texts: [String] = []
        var images: [NSImage] = []

        func clipboardTextMonitor(_ monitor: ClipboardTextMonitor, didCopy text: String) {
            texts.append(text)
        }

        func clipboardTextMonitor(_ monitor: ClipboardTextMonitor, didCopy image: NSImage) {
            images.append(image)
        }
    }
}

final class PillViewModelHistoryTests: XCTestCase {
    private var suiteName = ""
    private var captureRoot: URL?

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        if let captureRoot {
            try? FileManager.default.removeItem(at: captureRoot)
        }
        super.tearDown()
    }

    @MainActor
    func testCopyLinkWritesOriginalTextAndURLFlavor() throws {
        let viewModel = try makeViewModel()
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let link = TextClipItem(id: UUID(), createdAt: Date(), text: "https://example.com/path?q=1")

        viewModel.copyTextItem(link, to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), link.text)
        XCTAssertEqual(pasteboard.string(forType: .URL), link.text)
        XCTAssertEqual(viewModel.statusText, "Copied link")
    }

    @MainActor
    func testCopyPlainTextDoesNotAdvertiseAURL() throws {
        let viewModel = try makeViewModel()
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))
        let text = TextClipItem(id: UUID(), createdAt: Date(), text: "  Plain text  ")

        viewModel.copyTextItem(text, to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), text.text)
        XCTAssertNil(pasteboard.string(forType: .URL))
    }

    @MainActor
    func testSyncRetriesContextThatCouldNotBeReadBefore() throws {
        let viewModel = try makeViewModel()
        let (capture, contextURL) = try makeCaptureOnDisk(createdAt: 10, context: nil)
        viewModel.replaceHistory(screenshots: [capture], textClips: [])
        XCTAssertEqual(viewModel.contextPreview(for: capture), "context.md is unavailable")

        try "Saved after the capture appeared".write(to: contextURL, atomically: true, encoding: .utf8)
        viewModel.replaceHistory(screenshots: [capture], textClips: [])

        XCTAssertEqual(
            viewModel.contextPreview(for: capture),
            CaptureContextMarkdown.preview(from: "Saved after the capture appeared")
        )
    }

    @MainActor
    func testSyncFollowsContextEditedOrDeletedOnDisk() throws {
        let viewModel = try makeViewModel()
        let (capture, contextURL) = try makeCaptureOnDisk(createdAt: 10, context: "first")
        viewModel.replaceHistory(screenshots: [capture], textClips: [])
        XCTAssertEqual(viewModel.contextPreview(for: capture), CaptureContextMarkdown.preview(from: "first"))

        try "edited in Finder".write(to: contextURL, atomically: true, encoding: .utf8)
        try setModificationDate(Date().addingTimeInterval(60), of: contextURL)
        viewModel.replaceHistory(screenshots: [capture], textClips: [])
        XCTAssertEqual(viewModel.contextPreview(for: capture), CaptureContextMarkdown.preview(from: "edited in Finder"))

        try FileManager.default.removeItem(at: contextURL)
        viewModel.replaceHistory(screenshots: [capture], textClips: [])
        XCTAssertEqual(viewModel.contextPreview(for: capture), "context.md is unavailable")
    }

    @MainActor
    func testUnchangedContextFilesAreNotReadAgain() throws {
        let viewModel = try makeViewModel()
        let (existing, existingURL) = try makeCaptureOnDisk(createdAt: 10, context: "first")
        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        try setModificationDate(modified, of: existingURL)
        viewModel.replaceHistory(screenshots: [existing], textClips: [])

        // Same modification date, different bytes: a re-read would show them.
        try "not read".write(to: existingURL, atomically: true, encoding: .utf8)
        try setModificationDate(modified, of: existingURL)
        let (newer, _) = try makeCaptureOnDisk(createdAt: 20, context: "newer")
        viewModel.replaceScreenshot(newer)
        viewModel.replaceHistory(screenshots: [newer, existing], textClips: [])

        XCTAssertEqual(viewModel.contextPreview(for: existing), CaptureContextMarkdown.preview(from: "first"))
        XCTAssertEqual(viewModel.contextPreview(for: newer), CaptureContextMarkdown.preview(from: "newer"))
    }

    private func setModificationDate(_ date: Date, of url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    /// A capture laid out like the store's: <root>/<id>/screenshot.png beside
    /// an optional context.md.
    private func makeCaptureOnDisk(createdAt seconds: TimeInterval, context: String?) throws -> (CaptureItem, URL) {
        let root = captureRoot ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("PillViewModelHistoryTests-\(UUID().uuidString)", isDirectory: true)
        captureRoot = root
        let id = UUID()
        let directory = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let contextURL = directory.appendingPathComponent("context.md")
        if let context {
            try context.write(to: contextURL, atomically: true, encoding: .utf8)
        }
        let capture = CaptureItem(
            id: id,
            createdAt: Date(timeIntervalSince1970: seconds),
            imagePath: directory.appendingPathComponent("screenshot.png").path,
            thumbnailPath: directory.appendingPathComponent("thumbnail.png").path,
            context: .saved
        )
        return (capture, contextURL)
    }

    @MainActor
    func testHistoryIsCachedNewestFirstPerFilterAndFollowsChanges() throws {
        let viewModel = try makeViewModel()
        let older = TextClipItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 10), text: "older")
        let screenshot = makeScreenshot(createdAt: 20)
        viewModel.replaceHistory(screenshots: [screenshot], textClips: [older])

        XCTAssertEqual(viewModel.historyItems.map(\.id), [screenshot.id, older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .text).map(\.id), [older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .images).map(\.id), [screenshot.id])
        XCTAssertEqual(viewModel.historyItems(matching: .all), viewModel.historyItems)

        let newer = TextClipItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 30), text: "newer")
        viewModel.insertTextItem(newer)

        XCTAssertEqual(viewModel.historyItems.map(\.id), [newer.id, screenshot.id, older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .text).map(\.id), [newer.id, older.id])

        viewModel.remove(.screenshot(screenshot))

        XCTAssertEqual(viewModel.historyItems.map(\.id), [newer.id, older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .images), [])
    }

    @MainActor
    func testSyncingOnlyNewTextClipsUpdatesTheHistory() throws {
        let viewModel = try makeViewModel()
        let screenshot = makeScreenshot(createdAt: 20)
        viewModel.replaceHistory(screenshots: [screenshot], textClips: [])

        let text = TextClipItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 30), text: "text")
        viewModel.replaceHistory(screenshots: [screenshot], textClips: [text])

        XCTAssertEqual(viewModel.historyItems.map(\.id), [text.id, screenshot.id])
        XCTAssertEqual(viewModel.historyItems(matching: .text).map(\.id), [text.id])
    }

    @MainActor
    func testSyncingUnchangedHistoryPublishesNothing() throws {
        let viewModel = try makeViewModel()
        let screenshot = makeScreenshot(createdAt: 20)
        let text = TextClipItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 10), text: "text")
        viewModel.replaceHistory(screenshots: [screenshot], textClips: [text])

        var changes = 0
        let subscription = viewModel.objectWillChange.sink { changes += 1 }
        viewModel.replaceHistory(screenshots: [screenshot], textClips: [text])

        XCTAssertEqual(changes, 0)
        XCTAssertEqual(viewModel.historyItems.map(\.id), [screenshot.id, text.id])
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testUpdatingAScreenshotRefreshesTheCache() throws {
        let viewModel = try makeViewModel()
        let newer = makeScreenshot(createdAt: 30)
        let older = makeScreenshot(createdAt: 10)
        let text = TextClipItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 20), text: "text")
        viewModel.replaceHistory(screenshots: [newer, older], textClips: [text])

        let edited = CaptureItem(
            id: older.id,
            createdAt: older.createdAt,
            imagePath: "/tmp/edited.png",
            thumbnailPath: older.thumbnailPath,
            context: older.context
        )
        viewModel.updateScreenshot(edited)

        XCTAssertEqual(viewModel.historyItems, [.screenshot(newer), .text(text), .screenshot(edited)])
        XCTAssertEqual(viewModel.historyItems(matching: .images), [.screenshot(newer), .screenshot(edited)])
    }

    @MainActor
    private func makeViewModel() throws -> PillViewModel {
        suiteName = "Assist.PillViewModelHistoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return PillViewModel(
            settings: PillSettings(defaults: defaults),
            voiceContextService: VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        )
    }

    private func makeScreenshot(createdAt seconds: TimeInterval) -> CaptureItem {
        let id = UUID()
        return CaptureItem(
            id: id,
            createdAt: Date(timeIntervalSince1970: seconds),
            imagePath: "/tmp/\(id.uuidString)-missing.png",
            thumbnailPath: "/tmp/\(id.uuidString)-missing-thumbnail.png",
            context: .saved
        )
    }
}
