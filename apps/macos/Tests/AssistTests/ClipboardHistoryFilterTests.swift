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
