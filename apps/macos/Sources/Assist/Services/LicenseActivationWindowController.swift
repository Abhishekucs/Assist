import AppKit
import Combine
import SwiftUI

@MainActor
final class LicenseActivationWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: LicenseActivationViewModel
    private var allowsCloseAfterActivation = false
    private var appearanceSubscription: AnyCancellable?

    init(
        validationService: LicenseValidationService,
        activationStore: LicenseActivationStore,
        settings: PillSettings,
        initialErrorMessage: String? = nil,
        onActivated: @escaping (LicenseActivation) -> Void
    ) {
        viewModel = LicenseActivationViewModel(
            validationService: validationService,
            activationStore: activationStore
        )
        viewModel.errorMessage = initialErrorMessage
        viewModel.onActivated = onActivated

        let hostingController = NSHostingController(
            rootView: LicenseActivationView(viewModel: viewModel)
        )
        // Content runs under the transparent title bar. Without a safe area, the
        // window is sized to exactly the view's frame, with no title-bar inset.
        hostingController.safeAreaRegions = []
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: LicenseActivationView.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppIdentity.name) Activation"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .assistContentSurface
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController

        super.init(window: window)

        window.delegate = self
        appearanceSubscription = window.followAppearance(of: settings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showActivationWindow() {
        guard let window else { return }

        window.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func closeAfterActivation() {
        allowsCloseAfterActivation = true
        close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowsCloseAfterActivation {
            return true
        }

        NSApp.terminate(nil)
        return false
    }
}
