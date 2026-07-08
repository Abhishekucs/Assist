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
            contentRect: CGRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Assist"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 900, height: 620)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        return window
    }
}
