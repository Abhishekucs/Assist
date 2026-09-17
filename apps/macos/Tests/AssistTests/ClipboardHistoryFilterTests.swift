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

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
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
