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
    func testANewCaptureReadsOnlyItsOwnContext() throws {
        let viewModel = try makeViewModel()
        let (existing, existingURL) = try makeCaptureOnDisk(createdAt: 10, context: "first")
        viewModel.replaceHistory(screenshots: [existing], textClips: [])
        try "edited on disk".write(to: existingURL, atomically: true, encoding: .utf8)

        let (newer, _) = try makeCaptureOnDisk(createdAt: 20, context: "newer")
        viewModel.replaceScreenshot(newer)

        XCTAssertEqual(viewModel.contextPreview(for: existing), CaptureContextMarkdown.preview(from: "first"))
        XCTAssertEqual(viewModel.contextPreview(for: newer), CaptureContextMarkdown.preview(from: "newer"))

        // Updating a capture re-reads just that capture's file.
        viewModel.updateScreenshot(existing)
        XCTAssertEqual(viewModel.contextPreview(for: existing), CaptureContextMarkdown.preview(from: "edited on disk"))
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
