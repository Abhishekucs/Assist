import AppKit
import Combine
import SwiftUI

@MainActor
final class LicenseActivationWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: LicenseActivationViewModel
    private var allowsCloseAfterActivation = false
    private let appearanceSubscription: AnyCancellable

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

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: LicenseActivationView.minimumSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppIdentity.name) Activation"
        appearanceSubscription = window.applyAssistChrome(background: .assistContentSurface, appearanceFrom: settings)

        let hostingController = NSHostingController(
            rootView: LicenseActivationView(viewModel: viewModel)
                .environment(\.titleBarInset, window.titleBarInset)
        )
        // Without a safe area the window is exactly the view's size, and it
        // resizes with the view (for example, when an error needs more room).
        hostingController.safeAreaRegions = []
        window.contentViewController = hostingController

        super.init(window: window)

        window.delegate = self
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
