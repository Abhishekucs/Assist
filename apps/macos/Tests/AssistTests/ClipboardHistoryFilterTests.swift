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
    @MainActor
    func testHistoryIsCachedNewestFirstPerFilterAndFollowsChanges() {
        let viewModel = PillViewModel(
            settings: PillSettings(defaults: UserDefaults(suiteName: "Assist.PillViewModelHistoryTests.\(UUID().uuidString)")!),
            voiceContextService: VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        )
        let older = TextClipItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 10), text: "older")
        let screenshot = CaptureItem(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 20),
            imagePath: "/tmp/screenshot.png",
            thumbnailPath: "/tmp/thumbnail.png",
            context: .saved
        )
        viewModel.replaceHistory(screenshots: [screenshot], textClips: [older])

        XCTAssertEqual(viewModel.historyItems.map(\.id), [screenshot.id, older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .text).map(\.id), [older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .images).map(\.id), [screenshot.id])

        let newer = TextClipItem(id: UUID(), createdAt: Date(timeIntervalSince1970: 30), text: "newer")
        viewModel.textItems.insert(newer, at: 0)

        XCTAssertEqual(viewModel.historyItems.map(\.id), [newer.id, screenshot.id, older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .text).map(\.id), [newer.id, older.id])
        XCTAssertEqual(viewModel.historyItems(matching: .all).count, 3)
    }
}
