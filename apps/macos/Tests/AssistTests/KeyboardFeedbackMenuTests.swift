import AppKit
import XCTest
@testable import Assist

final class KeyboardFeedbackMenuTests: XCTestCase {
    @MainActor
    func testMenuSelectionsUpdateSharedSettingsAndSurviveReload() throws {
        _ = NSApplication.shared
        let suite = "Assist.KeyboardFeedbackMenuTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = KeyboardSoundSettings(defaults: defaults)
        let owner = KeyboardFeedbackMenuController(controller: KeyboardSoundController(settings: settings))
        let menu = NSMenu()
        owner.appendItems(to: menu)
        menu.performActionForItem(at: 0)
        menu.performActionForItem(at: 3)
        let sounds = try XCTUnwrap(menu.items[1].submenu)
        sounds.performActionForItem(at: try XCTUnwrap(sounds.items.firstIndex { $0.representedObject as? String == "topre" }))
        let designs = try XCTUnwrap(menu.items[4].submenu)
        designs.performActionForItem(at: try XCTUnwrap(designs.items.firstIndex { $0.representedObject as? String == "mint" }))
        XCTAssertTrue(settings.configuration.enabled)
        XCTAssertTrue(settings.configuration.visualizerEnabled)
        XCTAssertEqual(settings.configuration.pack, .topre)
        XCTAssertEqual(settings.configuration.visualizerStyle, .mint)
        XCTAssertEqual(KeyboardSoundSettings(defaults: defaults).configuration, settings.configuration)
        withExtendedLifetime(owner) {}
    }

    @MainActor
    func testSettingsChangesRefreshMenuWithoutReopeningIt() throws {
        let suite = "Assist.KeyboardFeedbackMenuTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = KeyboardSoundSettings(defaults: defaults)
        let owner = KeyboardFeedbackMenuController(controller: KeyboardSoundController(settings: settings))
        let menu = NSMenu()
        owner.appendItems(to: menu)
        settings.configuration.pack = .alpaca
        settings.configuration.visualizerStyle = .scarlet
        settings.configuration.visualizerPosition = .bottomRight
        for index in [1, 4, 5] {
            let checked = try XCTUnwrap(menu.items[index].submenu).items.filter { $0.state == .on }
            XCTAssertEqual(checked.count, 1)
            XCTAssertTrue(menu.items[index].title.hasSuffix(try XCTUnwrap(checked.first).title))
        }
        XCTAssertFalse(settings.configuration.enabled)
        XCTAssertFalse(settings.configuration.visualizerEnabled)
        withExtendedLifetime(owner) {}
    }
}
