import AppKit
import SwiftUI
import XCTest
@testable import Assist

final class AssistWindowTests: XCTestCase {
    @MainActor
    func testActivationWindowMatchesItsContentAndIsPaintedEdgeToEdge() throws {
        _ = NSApplication.shared
        let (settings, _, cleanUp) = try makeSettings()
        defer { cleanUp() }
        let controller = LicenseActivationWindowController(
            validationService: LicenseValidationService(),
            activationStore: LicenseActivationStore(),
            settings: settings,
            onActivated: { _ in }
        )
        defer { controller.closeAfterActivation() }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        window.orderFront(nil)
        settle()

        XCTAssertEqual(window.frame.size, LicenseActivationView.size)
        XCTAssertEqual(contentView.bounds.size, LicenseActivationView.size)
        XCTAssertTrue(window.isOpaque)
        XCTAssertEqual(try alpha(of: contentView, atPointFromTop: contentView.bounds.height - 1), 1, accuracy: 0.01)
    }

    @MainActor
    func testControlPanelMinimumSizeIsTheDeclaredContentMinimum() throws {
        _ = NSApplication.shared
        let (settings, defaults, cleanUp) = try makeSettings()
        defer { cleanUp() }
        let voice = VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        let controller = ControlPanelWindowController(
            settings: settings,
            pillViewModel: PillViewModel(settings: settings, voiceContextService: voice),
            keyboardSounds: KeyboardSoundController(settings: KeyboardSoundSettings(defaults: defaults))
        )
        controller.showWindow()
        let window = try XCTUnwrap(NSApp.windows.first { $0.contentView is NSHostingView<ControlPanelView> })
        defer { window.close() }
        settle()

        XCTAssertEqual(window.contentMinSize, ControlPanelView.minimumSize)
        window.setFrame(NSRect(x: 0, y: 0, width: 400, height: 300), display: true)
        settle()
        XCTAssertEqual(window.frame.size, ControlPanelView.minimumSize)
        XCTAssertTrue(window.isOpaque)
    }

    @MainActor
    func testWindowAppearanceFollowsTheSetting() throws {
        let (settings, _, cleanUp) = try makeSettings()
        defer { cleanUp() }
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        let subscription = window.followAppearance(of: settings)
        defer { subscription.cancel() }

        XCTAssertNil(window.appearance)
        settings.appAppearance = .dark
        XCTAssertEqual(window.appearance?.name, .darkAqua)
        settings.appAppearance = .light
        XCTAssertEqual(window.appearance?.name, .aqua)
        settings.appAppearance = .system
        XCTAssertNil(window.appearance)
    }

    func testSidebarCountsEveryFilterInOnePass() {
        let text = TextClipItem(id: UUID(), createdAt: Date(), text: "hello")
        let items: [ClipboardHistoryItem] = [.text(text)]
        let counts = LibrarySidebar.counts(for: items)

        XCTAssertEqual(counts[.all], 1)
        XCTAssertEqual(counts[.text], 1)
        XCTAssertNil(counts[.images])
    }

    private func makeSettings() throws -> (PillSettings, UserDefaults, () -> Void) {
        let suite = "Assist.AssistWindowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (PillSettings(defaults: defaults), defaults, { defaults.removePersistentDomain(forName: suite) })
    }

    @MainActor
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    }

    @MainActor
    private func alpha(of view: NSView, atPointFromTop y: CGFloat) throws -> CGFloat {
        view.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsHigh) / view.bounds.height
        let row = min(rep.pixelsHigh - 1, Int(y * scale))
        return try XCTUnwrap(rep.colorAt(x: rep.pixelsWide / 2, y: row)).alphaComponent
    }
}
