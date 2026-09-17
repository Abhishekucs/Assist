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
        settings.appAppearance = .light
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

        XCTAssertTrue(waitUntil { window.frame.size == LicenseActivationView.size }, "\(window.frame.size)")
        XCTAssertEqual(contentView.bounds.size, LicenseActivationView.size)
        // The form lays out from the window's top edge, under the transparent title bar.
        let hostingController = try XCTUnwrap(window.contentViewController as? NSHostingController<LicenseActivationView>)
        XCTAssertEqual(hostingController.safeAreaRegions, [])
        // The title bar strip and the bottom edge are where an inset used to leave gaps.
        let bounds = contentView.bounds
        let samples = try colors(of: contentView, at: [
            CGPoint(x: bounds.width - 4, y: 0.5),
            CGPoint(x: 4, y: bounds.height - 0.5),
            CGPoint(x: bounds.width - 4, y: bounds.height - 0.5),
        ])
        let background = AssistTheme(colorScheme: .light).background
        for sample in samples {
            XCTAssertEqual(sample.alphaComponent, 1)
            XCTAssertTrue(sample.matches(background), "\(sample)")
        }
        XCTAssertTrue(try resolvedColor(of: window.backgroundColor, in: window).matches(background))
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
        let window = try XCTUnwrap(NSApp.windows.first { $0.isVisible && $0.contentView is NSHostingView<ControlPanelView> })
        defer { window.close() }

        XCTAssertTrue(
            waitUntil { window.contentMinSize == ControlPanelView.minimumSize },
            "contentMinSize is \(window.contentMinSize)"
        )
        window.setFrame(NSRect(x: 0, y: 0, width: 400, height: 300), display: true)
        XCTAssertTrue(waitUntil { window.frame.size == ControlPanelView.minimumSize }, "\(window.frame.size)")
        let surface = try resolvedColor(of: window.backgroundColor, in: window)
        XCTAssertEqual(surface.alphaComponent, 1)
        XCTAssertTrue(surface.matches(AssistTheme(colorScheme: window.effectiveAppearance.isDark ? .dark : .light).sidebar))
    }

    @MainActor
    func testWindowAppearanceFollowsTheSetting() throws {
        _ = NSApplication.shared
        let (settings, _, cleanUp) = try makeSettings()
        defer { cleanUp() }
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
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
        let counts = LibrarySidebar.counts(for: [.text(text)])

        XCTAssertEqual(counts[.all], 1)
        XCTAssertEqual(counts[.text], 1)
        XCTAssertNil(counts[.images])
    }

    private func makeSettings() throws -> (PillSettings, UserDefaults, () -> Void) {
        let suite = "Assist.AssistWindowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (PillSettings(defaults: defaults), defaults, { defaults.removePersistentDomain(forName: suite) })
    }

    /// Spins the run loop until `condition` holds, so layout passes finish
    /// without a fixed delay; returns false after `timeout`.
    @MainActor
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return true
    }

    /// sRGB colors of the view's rendering at points measured from its top-left.
    @MainActor
    private func colors(of view: NSView, at points: [CGPoint]) throws -> [NSColor] {
        view.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsHigh) / view.bounds.height
        return try points.map { point in
            let x = min(rep.pixelsWide - 1, Int(point.x * scale))
            let y = min(rep.pixelsHigh - 1, Int(point.y * scale))
            return try XCTUnwrap(rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        }
    }

    @MainActor
    private func resolvedColor(of color: NSColor, in window: NSWindow) throws -> NSColor {
        var resolved: NSColor?
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB)
        }
        return try XCTUnwrap(resolved)
    }
}

private extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
}

private extension NSColor {
    func matches(_ color: Color, tolerance: CGFloat = 0.02) -> Bool {
        guard let expected = NSColor(color).usingColorSpace(.sRGB) else { return false }
        return abs(redComponent - expected.redComponent) <= tolerance
            && abs(greenComponent - expected.greenComponent) <= tolerance
            && abs(blueComponent - expected.blueComponent) <= tolerance
    }
}
