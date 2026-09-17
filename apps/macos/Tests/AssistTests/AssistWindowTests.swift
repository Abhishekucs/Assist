import AppKit
import SwiftUI
import XCTest
@testable import Assist

final class AssistWindowTests: XCTestCase {
    @MainActor
    func testActivationWindowMatchesItsFormAndIsPaintedEdgeToEdge() throws {
        let (settings, _, cleanUp) = try makeSettings()
        defer { cleanUp() }
        let controller = makeActivationController(settings: settings)
        defer { controller.closeAfterActivation() }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        window.orderFront(nil)

        XCTAssertTrue(waitUntil { window.frame.size == LicenseActivationView.minimumSize }, "\(window.frame.size)")
        let rendering = try Rendering(of: contentView)
        let background = AssistTheme(colorScheme: .light).background
        // The title bar strip and the bottom edge are where an inset used to leave gaps.
        for point in [
            CGPoint(x: rendering.width - 4, y: 0.5),
            CGPoint(x: 4, y: rendering.height - 0.5),
            CGPoint(x: rendering.width - 4, y: rendering.height - 0.5),
        ] {
            XCTAssertTrue(rendering.color(at: point).matches(background), "\(point)")
        }
        // The form starts below the title bar that it runs under.
        let firstInkRow = try XCTUnwrap(rendering.firstRow(differingFrom: background, inColumns: 32...300))
        XCTAssertGreaterThanOrEqual(firstInkRow, window.titleBarInset)
        XCTAssertTrue(try resolvedColor(of: window.backgroundColor, in: window).matches(background))
    }

    @MainActor
    func testActivationWindowGrowsToKeepItsActionsVisibleForLongErrors() throws {
        let (settings, _, cleanUp) = try makeSettings()
        defer { cleanUp() }
        let longError = String(repeating: "The license server returned a long explanation. ", count: 20)
        let controller = makeActivationController(settings: settings, initialErrorMessage: longError)
        defer { controller.closeAfterActivation() }
        let window = try XCTUnwrap(controller.window)
        let contentView = try XCTUnwrap(window.contentView)
        window.orderFront(nil)

        XCTAssertTrue(waitUntil { window.frame.height > LicenseActivationView.minimumSize.height }, "\(window.frame.size)")
        XCTAssertEqual(window.frame.width, LicenseActivationView.minimumSize.width)
        // The Quit and Activate row keeps its bottom padding instead of being clipped.
        let rendering = try Rendering(of: contentView)
        let background = AssistTheme(colorScheme: .light).background
        let lastInkRow = try XCTUnwrap(rendering.lastRow(differingFrom: background, inColumns: 32...448))
        XCTAssertLessThan(lastInkRow, rendering.height - 24)
    }

    @MainActor
    func testControlPanelMinimumSizeAndLayoutUnderTheTitleBar() throws {
        let (settings, defaults, cleanUp) = try makeSettings()
        defer { cleanUp() }
        let voice = VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        let controller = ControlPanelWindowController(
            settings: settings,
            pillViewModel: PillViewModel(settings: settings, voiceContextService: voice),
            keyboardSounds: KeyboardSoundController(settings: KeyboardSoundSettings(defaults: defaults))
        )
        let window = controller.preparedWindow()
        let contentView = try XCTUnwrap(window.contentView)
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        XCTAssertTrue(
            waitUntil { window.contentMinSize == ControlPanelView.minimumSize },
            "contentMinSize is \(window.contentMinSize)"
        )
        window.setFrame(NSRect(x: 0, y: 0, width: 400, height: 300), display: true)
        XCTAssertTrue(waitUntil { window.frame.size == ControlPanelView.minimumSize }, "\(window.frame.size)")

        let theme = AssistTheme(colorScheme: .light)
        let rendering = try Rendering(of: contentView)
        // The content pane reaches up under the title bar, inset from the window edge.
        let paneX = rendering.width - 20
        let paneTop = AssistDesignTokens.AppLayout.paneInset
        XCTAssertTrue(rendering.color(at: CGPoint(x: paneX, y: paneTop - 4)).matches(theme.sidebar))
        XCTAssertTrue(rendering.color(at: CGPoint(x: paneX, y: paneTop + 4)).matches(theme.background))
        // The sidebar's wordmark starts below the title bar.
        let firstSidebarInk = try XCTUnwrap(rendering.firstRow(differingFrom: theme.sidebar, inColumns: 24...170))
        XCTAssertGreaterThanOrEqual(firstSidebarInk, window.titleBarInset)
        XCTAssertTrue(try resolvedColor(of: window.backgroundColor, in: window).matches(theme.sidebar))
    }

    @MainActor
    func testTitleBarInsetFollowsTheWindowsTitleBar() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        let metrics = WindowTitleBarMetrics(window: window)
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let titleBarOnly = metrics.inset
        XCTAssertGreaterThan(titleBarOnly, 0)

        // A toolbar makes the title bar taller; removing it restores the height.
        window.toolbar = NSToolbar(identifier: "AssistWindowTests")
        XCTAssertTrue(waitUntil { metrics.inset > titleBarOnly }, "\(metrics.inset)")
        XCTAssertEqual(metrics.inset, window.titleBarInset)
        window.toolbar = nil
        XCTAssertTrue(waitUntil { metrics.inset == titleBarOnly }, "\(metrics.inset)")
    }

    @MainActor
    func testWindowAppearanceFollowsTheSetting() throws {
        _ = NSApplication.shared
        let (settings, _, cleanUp) = try makeSettings(appearance: .system)
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

    @MainActor
    private func makeActivationController(
        settings: PillSettings,
        initialErrorMessage: String? = nil
    ) -> LicenseActivationWindowController {
        _ = NSApplication.shared
        return LicenseActivationWindowController(
            validationService: LicenseValidationService(),
            activationStore: LicenseActivationStore(),
            settings: settings,
            initialErrorMessage: initialErrorMessage,
            onActivated: { _ in }
        )
    }

    /// Settings in a throwaway defaults suite; light appearance unless stated,
    /// so rendered colors are predictable.
    @MainActor
    private func makeSettings(appearance: AppAppearance = .light) throws -> (PillSettings, UserDefaults, () -> Void) {
        let suite = "Assist.AssistWindowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = PillSettings(defaults: defaults)
        settings.appAppearance = appearance
        return (settings, defaults, { defaults.removePersistentDomain(forName: suite) })
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

    @MainActor
    private func resolvedColor(of color: NSColor, in window: NSWindow) throws -> NSColor {
        var resolved: NSColor?
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB)
        }
        return try XCTUnwrap(resolved)
    }
}

/// A view's rendering, addressed in points from its top-left corner.
@MainActor
private struct Rendering {
    let width: CGFloat
    let height: CGFloat
    private let rep: NSBitmapImageRep
    private let scale: CGFloat

    init(of view: NSView) throws {
        view.layoutSubtreeIfNeeded()
        rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        width = view.bounds.width
        height = view.bounds.height
        scale = CGFloat(rep.pixelsHigh) / view.bounds.height
    }

    func color(at point: CGPoint) -> NSColor {
        pixel(x: Int(point.x * scale), y: Int(point.y * scale))
    }

    /// The top, in points, of the first pixel row that has a pixel in
    /// `columns` (points) differing from `background`.
    func firstRow(differingFrom background: Color, inColumns columns: ClosedRange<CGFloat>) -> CGFloat? {
        (0..<rep.pixelsHigh).first { hasInk(row: $0, differingFrom: background, inColumns: columns) }
            .map { CGFloat($0) / scale }
    }

    /// The top, in points, of the last such pixel row.
    func lastRow(differingFrom background: Color, inColumns columns: ClosedRange<CGFloat>) -> CGFloat? {
        (0..<rep.pixelsHigh).last { hasInk(row: $0, differingFrom: background, inColumns: columns) }
            .map { CGFloat($0) / scale }
    }

    private func hasInk(row: Int, differingFrom background: Color, inColumns columns: ClosedRange<CGFloat>) -> Bool {
        let first = Int(columns.lowerBound * scale)
        let last = min(rep.pixelsWide - 1, Int(columns.upperBound * scale))
        return (first...last).contains { !pixel(x: $0, y: row).matches(background, tolerance: 0.04) }
    }

    private func pixel(x: Int, y: Int) -> NSColor {
        let x = min(max(0, x), rep.pixelsWide - 1)
        let y = min(max(0, y), rep.pixelsHigh - 1)
        return rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) ?? .clear
    }
}

private extension NSColor {
    func matches(_ color: Color, tolerance: CGFloat = 0.02) -> Bool {
        guard let expected = NSColor(color).usingColorSpace(.sRGB) else { return false }
        return alphaComponent > 0.99
            && abs(redComponent - expected.redComponent) <= tolerance
            && abs(greenComponent - expected.greenComponent) <= tolerance
            && abs(blueComponent - expected.blueComponent) <= tolerance
    }
}
