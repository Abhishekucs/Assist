import AppKit
import SwiftUI

@MainActor
final class LicenseActivationWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: LicenseActivationViewModel
    private var allowsCloseAfterActivation = false

    init(
        validationService: LicenseValidationService,
        activationStore: LicenseActivationStore,
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppIdentity.name) Activation"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
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
