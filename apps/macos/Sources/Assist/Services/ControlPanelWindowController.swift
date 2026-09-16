import AppKit
import Combine
import SwiftUI

@MainActor
final class ControlPanelWindowController: NSObject, NSWindowDelegate {
    private let settings: PillSettings
    private let pillViewModel: PillViewModel
    private let keyboardSounds: KeyboardSoundController
    private var window: NSWindow?
    private var appearanceSubscription: AnyCancellable?

    init(settings: PillSettings, pillViewModel: PillViewModel, keyboardSounds: KeyboardSoundController) {
        self.settings = settings
        self.pillViewModel = pillViewModel
        self.keyboardSounds = keyboardSounds
    }

    func showWindow() {
        let window = window ?? makeWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hostingView = NSHostingView(
            rootView: ControlPanelView(settings: settings, viewModel: pillViewModel, keyboardSounds: keyboardSounds)
        )
        // Content runs under the transparent title bar. Without a safe area, the
        // hosting view turns ControlPanelView's minimum frame into the window's
        // minimum size as-is, with no title-bar inset added.
        hostingView.safeAreaRegions = []
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Assist"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .assistWindowSurface
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        appearanceSubscription = window.followAppearance(of: settings)
        self.window = window
        return window
    }
}
