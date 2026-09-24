import AppKit
import SwiftUI
import XCTest
@testable import Assist

final class ModuleVisibilityTests: XCTestCase {
    @MainActor
    func testRetainedHostingViewStopsOnCloseAndResumesOnReopen() {
        let service = CountingModuleService()
        let window = makeWindow(service: service)
        defer { window.contentView = nil; window.close() }
        XCTAssertEqual(service.viewers, 0, "Preparing a hidden window must not start polling")

        window.orderFront(nil)
        XCTAssertTrue(waitUntil { service.viewers == 1 })
        window.close()
        XCTAssertNotNil(window.contentView, "The control panel retains its hosting view")
        XCTAssertTrue(waitUntil { service.viewers == 0 })

        window.orderFront(nil)
        XCTAssertTrue(waitUntil { service.viewers == 1 })
        XCTAssertEqual(service.starts, 2)
        window.orderOut(nil)
        XCTAssertTrue(waitUntil { service.viewers == 0 })
        XCTAssertEqual(service.stops, 2)
    }

    @MainActor
    func testClosingOnePresentationKeepsTheOtherActive() {
        let service = CountingModuleService()
        let controlWindow = makeWindow(service: service)
        let notchWindow = makeWindow(service: service)
        defer {
            controlWindow.contentView = nil
            notchWindow.contentView = nil
            controlWindow.close()
            notchWindow.close()
        }
        controlWindow.orderFront(nil)
        notchWindow.orderFront(nil)
        XCTAssertTrue(waitUntil { service.viewers == 2 })

        controlWindow.close()
        XCTAssertTrue(waitUntil { service.viewers == 1 })
        controlWindow.orderFront(nil)
        XCTAssertTrue(waitUntil { service.viewers == 2 })
        notchWindow.close()
        XCTAssertTrue(waitUntil { service.viewers == 1 })
        controlWindow.close()
        XCTAssertTrue(waitUntil { service.viewers == 0 })
        XCTAssertEqual(service.starts, service.stops)
    }

    @MainActor
    func testMinimizingStopsPollingAndRestoringResumesIt() {
        let service = CountingModuleService()
        let window = makeWindow(service: service)
        defer { window.contentView = nil; window.close() }
        window.orderFront(nil)
        XCTAssertTrue(waitUntil { service.viewers == 1 })
        window.miniaturize(nil)
        XCTAssertTrue(waitUntil { window.isMiniaturized && service.viewers == 0 })
        window.deminiaturize(nil)
        XCTAssertTrue(waitUntil { !window.isMiniaturized && service.viewers == 1 })
    }

    @MainActor
    func testRemovingThePresentationBalancesItsSubscription() {
        let service = CountingModuleService()
        let window = makeWindow(service: service)
        defer { window.close() }
        window.orderFront(nil)
        XCTAssertTrue(waitUntil { service.viewers == 1 })
        window.contentView = nil
        XCTAssertTrue(waitUntil { service.viewers == 0 })
        XCTAssertEqual(service.starts, service.stops)
    }

    @MainActor
    func testReplacingServiceAndHidingViewBalancesSubscriptions() {
        _ = NSApplication.shared
        let first = CountingModuleService()
        let second = CountingModuleService()
        let window = makeWindow(service: first)
        let view = ModuleVisibilityView()
        view.setService(first)
        window.contentView = view
        defer { window.contentView = nil; window.close() }
        window.orderFront(nil)
        XCTAssertTrue(waitUntil { first.viewers == 1 })

        view.setService(second)
        XCTAssertEqual(first.viewers, 0)
        XCTAssertEqual(second.viewers, 1)
        view.setService(second)
        XCTAssertEqual(second.starts, 1)
        view.isHidden = true
        XCTAssertEqual(second.viewers, 0)
        view.isHidden = false
        XCTAssertEqual(second.viewers, 1)
        view.detach()
        XCTAssertEqual(second.viewers, 0)
    }

    @MainActor
    private func makeWindow(service: CountingModuleService) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let hostingView = NSHostingView(rootView: Color.clear.background {
            ModuleVisibilityObserver(service: service)
        })
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        return window
    }

    @MainActor
    private func waitUntil(_ predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return predicate()
    }
}

@MainActor
private final class CountingModuleService: VisibleModuleService {
    private(set) var viewers = 0
    private(set) var starts = 0
    private(set) var stops = 0

    func start() {
        viewers += 1
        starts += 1
    }

    func stop() {
        viewers -= 1
        stops += 1
    }
}
