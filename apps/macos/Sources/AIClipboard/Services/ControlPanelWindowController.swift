import AppKit
import SwiftUI

@MainActor
final class ControlPanelWindowController: NSObject, NSWindowDelegate {
    private let settings: PillSettings
    private let pillViewModel: PillViewModel
    private var window: NSWindow?

    init(settings: PillSettings, pillViewModel: PillViewModel) {
        self.settings = settings
        self.pillViewModel = pillViewModel
    }

    func showWindow() {
        let window = window ?? makeWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let contentView = ControlPanelView(settings: settings, viewModel: pillViewModel)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 700, height: 520)
        window.toolbarStyle = .unified
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        return window
    }
}
