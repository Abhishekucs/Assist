import XCTest
@testable import Assist

final class KeyboardVisualizerTests: XCTestCase {
    @MainActor
    func testOnlyHeldKnownKeysAreVisibleAndHidingClearsThem() {
        let state = KeyboardVisualizerState()
        state.receive(.init(keyCode: 0, phase: .down))
        XCTAssertTrue(state.pressedKeys.isEmpty)
        state.setVisible(true)
        // Both Command keys and a letter can be down together.
        for code: UInt16 in [55, 54, 0, 0, 65535] {
            state.receive(.init(keyCode: code, phase: .down))
        }
        XCTAssertEqual(state.pressedKeys, [55, 54, 0])
        state.receive(.init(keyCode: 55, phase: .up))
        XCTAssertEqual(state.pressedKeys, [54, 0])
        state.receive(.init(keyCode: 1, phase: .up))
        XCTAssertEqual(state.pressedKeys, [54, 0])
        state.setVisible(false)
        XCTAssertTrue(state.pressedKeys.isEmpty)
        state.setVisible(true)
        XCTAssertTrue(state.pressedKeys.isEmpty)
        state.receive(.init(keyCode: 49, phase: .down))
        state.reset()
        XCTAssertTrue(state.pressedKeys.isEmpty)
    }

    func testLayoutHasUniquePhysicalCodesAndAlignedRows() {
        let keys = KeyboardVisualizerLayout.rows.flatMap { $0 }
        XCTAssertEqual(keys.count, KeyboardVisualizerLayout.keyCodes.count)
        for row in KeyboardVisualizerLayout.rows {
            XCTAssertEqual(row.reduce(0) { $0 + $1.units }, KeyboardVisualizerLayout.rowUnits)
        }
        for code: UInt16 in [0, 49, 36, 51, 53, 54, 55, 56, 60, 58, 61, 59, 62, 63, 123, 124, 125, 126] {
            XCTAssertTrue(KeyboardVisualizerLayout.keyCodes.contains(code), "Missing code \(code)")
        }
    }

    func testPointerPlacementFlipsAtEdgesAndStaysOnEachDisplay() {
        let displays = [CGRect(x: 0, y: 40, width: 1440, height: 830),
                        CGRect(x: -1920, y: -500, width: 1920, height: 1080)]
        for display in displays {
            for pointer in [CGPoint(x: display.midX, y: display.midY),
                            CGPoint(x: display.minX + 2, y: display.minY + 2),
                            CGPoint(x: display.maxX - 2, y: display.maxY - 2),
                            CGPoint(x: display.maxX - 2, y: display.minY + 2)] {
                let frame = KeyboardVisualizerPlacement.frame(position: .followPointer, pointer: pointer, visibleFrame: display)
                XCTAssertTrue(display.contains(frame))
                XCTAssertFalse(frame.contains(pointer))
                XCTAssertEqual(frame.size, KeyboardVisualizerPlacement.size)
            }
        }
    }

    func testPinnedCornersIgnorePointerMovementAndAvoidDockArea() {
        let visible = CGRect(x: -1600, y: 60, width: 1600, height: 900)
        for position in [KeyboardVisualizerPosition.bottomLeft, .bottomRight] {
            let first = KeyboardVisualizerPlacement.frame(position: position, pointer: .zero, visibleFrame: visible)
            let second = KeyboardVisualizerPlacement.frame(position: position, pointer: CGPoint(x: -900, y: 400), visibleFrame: visible)
            XCTAssertEqual(first, second)
            XCTAssertEqual(first.minY, visible.minY + KeyboardVisualizerPlacement.margin)
            XCTAssertTrue(visible.contains(first))
        }
    }

    func testOldSoundSettingsDecodeWithoutResettingUserChoices() throws {
        let old = Data(#"{"enabled":true,"pack":"soft","volume":0.72,"stereo":false}"#.utf8)
        var configuration = try JSONDecoder().decode(KeyboardSoundConfiguration.self, from: old)
        XCTAssertTrue(configuration.enabled)
        XCTAssertEqual(configuration.pack, .soft)
        XCTAssertEqual(configuration.volume, 0.72)
        XCTAssertFalse(configuration.stereo)
        XCTAssertFalse(configuration.visualizerEnabled)
        XCTAssertEqual(configuration.visualizerPosition, .followPointer)
        configuration.visualizerEnabled = true
        configuration.visualizerPosition = .bottomRight
        let reloaded = try JSONDecoder().decode(KeyboardSoundConfiguration.self, from: JSONEncoder().encode(configuration))
        XCTAssertEqual(configuration, reloaded)
    }
}
