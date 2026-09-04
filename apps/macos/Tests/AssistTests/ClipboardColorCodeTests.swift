import XCTest
@testable import Assist

final class ClipboardColorCodeTests: XCTestCase {
    func testParsesSupportedStandaloneHexColorCodes() throws {
        let short = try XCTUnwrap(ClipboardColorCode(" #3AF "))
        XCTAssertEqual(short.displayValue, "#33AAFF")
        XCTAssertEqual(short.red, 0x33.doubleComponent, accuracy: 0.0001)
        XCTAssertEqual(short.green, 0xAA.doubleComponent, accuracy: 0.0001)
        XCTAssertEqual(short.blue, 1, accuracy: 0.0001)
        XCTAssertEqual(short.alpha, 1, accuracy: 0.0001)

        let withAlpha = try XCTUnwrap(ClipboardColorCode("0x33669980"))
        XCTAssertEqual(withAlpha.displayValue, "#33669980")
        XCTAssertEqual(withAlpha.alpha, 0x80.doubleComponent, accuracy: 0.0001)
    }

    func testRejectsNonStandaloneAndMalformedColorCodes() {
        XCTAssertNil(ClipboardColorCode("Use #336699 for the background"))
        XCTAssertNil(ClipboardColorCode("336699"))
        XCTAssertNil(ClipboardColorCode("#12"))
        XCTAssertNil(ClipboardColorCode("#GGHHII"))
    }

    func testChoosesReadableForegroundFromLuminance() throws {
        XCTAssertTrue(try XCTUnwrap(ClipboardColorCode("#FFFFFF")).usesDarkForeground)
        XCTAssertFalse(try XCTUnwrap(ClipboardColorCode("#111111")).usesDarkForeground)
    }
}

private extension BinaryInteger {
    var doubleComponent: Double {
        Double(self) / 255
    }
}
