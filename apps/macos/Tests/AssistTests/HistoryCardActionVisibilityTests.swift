import XCTest
@testable import Assist

final class HistoryCardActionVisibilityTests: XCTestCase {
    func testActionTrayIsHiddenUntilTheCardOrAnActionOwnsHover() {
        XCTAssertFalse(
            HistoryCardActionVisibility.isVisible(
                cardHovered: false,
                deleteActionHovered: false,
                contextActionHovered: false
            )
        )

        XCTAssertTrue(
            HistoryCardActionVisibility.isVisible(
                cardHovered: true,
                deleteActionHovered: false,
                contextActionHovered: false
            )
        )
        XCTAssertTrue(
            HistoryCardActionVisibility.isVisible(
                cardHovered: false,
                deleteActionHovered: true,
                contextActionHovered: false
            )
        )
        XCTAssertTrue(
            HistoryCardActionVisibility.isVisible(
                cardHovered: false,
                deleteActionHovered: false,
                contextActionHovered: true
            )
        )
    }
}
