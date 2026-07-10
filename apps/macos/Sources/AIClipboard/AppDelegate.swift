import AppKit
import Combine
import CoreText

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var controlPanelController: ControlPanelWindowController?
    private var licenseActivationController: LicenseActivationWindowController?
    private var pillViewModel: PillViewModel?
    private var statusItem: NSStatusItem?
    private var settingsCancellable: AnyCancellable?
    private let licenseActivationStore = LicenseActivationStore()
    private let licenseValidationService = LicenseValidationService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerBundledFonts()

        guard LicenseActivationRequirement.isRequired else {
            startMainApp()
            return
        }

        Task {
            await validateLicenseAndStart()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    private func validateLicenseAndStart() async {
        do {
            guard let activation = try licenseActivationStore.load() else {
                showLicenseActivationWindow()
                return
            }

            let validatedActivation = try await licenseValidationService.validate(activation)
            try licenseActivationStore.save(validatedActivation)
            startMainApp()
        } catch {
            licenseActivationStore.clear()
            showLicenseActivationWindow(
                initialErrorMessage: "Saved activation could not be verified. Enter your license key again."
            )
        }
    }

    private func showLicenseActivationWindow(initialErrorMessage: String? = nil) {
        let activationController = LicenseActivationWindowController(
            validationService: licenseValidationService,
            activationStore: licenseActivationStore,
            initialErrorMessage: initialErrorMessage
        ) { [weak self] _ in
            self?.licenseActivationController?.closeAfterActivation()
            self?.licenseActivationController = nil
            self?.startMainApp()
        }

        licenseActivationController = activationController
        activationController.showActivationWindow()
    }

    private func startMainApp() {
        guard coordinator == nil else { return }

        let store = CaptureStore()
        let settings = PillSettings()
        let pillViewModel = PillViewModel(settings: settings)
        let windowManager = WindowManager(pillViewModel: pillViewModel, settings: settings)
        let controlPanelController = ControlPanelWindowController(settings: settings, pillViewModel: pillViewModel)
        let coordinator = AppCoordinator(
            windowManager: windowManager,
            captureService: CaptureService(),
            store: store,
            pillViewModel: pillViewModel
        )

        pillViewModel.onOpenControls = { [weak controlPanelController] in
            controlPanelController?.showWindow()
        }

        self.pillViewModel = pillViewModel
        self.controlPanelController = controlPanelController
        self.coordinator = coordinator
        configureStatusItem(settings: settings)
        coordinator.start()
        controlPanelController.showWindow()
    }

    private func registerBundledFonts() {
        guard let fontsURL = Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true),
              let fontURLs = try? FileManager.default.contentsOfDirectory(at: fontsURL, includingPropertiesForKeys: nil) else {
            return
        }

        for fontURL in fontURLs where ["ttf", "otf"].contains(fontURL.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }

    private func configureStatusItem(settings: PillSettings) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = AssistLogoImageStore.menuBarImage() ?? NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: AppIdentity.name
        )
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = AppIdentity.name

        let menu = NSMenu()
        menu.addItem(menuItem(title: "Open Assist", action: #selector(openControls), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "Test Screenshot", action: #selector(testScreenshot), keyEquivalent: ""))
        menu.addItem(menuItem(title: "Test Overlay", action: #selector(testOverlay), keyEquivalent: ""))
        menu.addItem(menuItem(title: "Open Log", action: #selector(openDebugLog), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "Quit \(AppIdentity.name)", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        item.isVisible = settings.showMenuBarIcon
        statusItem = item

        settingsCancellable = settings.$showMenuBarIcon.sink { [weak self] isVisible in
            self?.statusItem?.isVisible = isVisible
        }
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func openControls() {
        pillViewModel?.willShowHistory()
        controlPanelController?.showWindow()
    }

    @objc private func testScreenshot() {
        pillViewModel?.testScreenshot()
    }

    @objc private func testOverlay() {
        pillViewModel?.testOverlay()
    }

    @objc private func openDebugLog() {
        pillViewModel?.openDebugLog()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
