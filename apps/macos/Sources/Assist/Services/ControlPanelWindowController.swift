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
        let window = preparedWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// The library window, created on first use without showing it.
    func preparedWindow() -> NSWindow {
        window ?? makeWindow()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 1040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Assist"
        appearanceSubscription = window.applyAssistChrome(background: .assistWindowSurface, appearanceFrom: settings)

        let hostingView = NSHostingView(
            rootView: ControlPanelView(settings: settings, viewModel: pillViewModel, keyboardSounds: keyboardSounds)
                .environment(\.titleBarInset, window.titleBarInset)
        )
        // Without a safe area, the hosting view turns ControlPanelView's minimum
        // frame into the window's minimum size as-is.
        hostingView.safeAreaRegions = []
        window.contentView = hostingView
        window.delegate = self
        window.center()
        self.window = window
        return window
    }
}
