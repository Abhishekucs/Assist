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
        DebugLogger.log("app.launch", [
            "bundle": Bundle.main.bundleIdentifier ?? "unknown",
            "version": appVersion,
            "build": appBuild,
            "development": "\(AppIdentity.isDevelopmentBundle)",
            "licenseRequired": "\(LicenseActivationRequirement.isRequired)"
        ])

        registerBundledFonts()

        guard LicenseActivationRequirement.isRequired else {
            DebugLogger.log("license.validation.skipped", ["reason": "not-required"])
            startMainApp()
            return
        }

        Task {
            await validateLicenseAndStart()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DebugLogger.log("app.terminate")
        coordinator?.stop()
    }

    private func validateLicenseAndStart() async {
        DebugLogger.log("license.validation.start")

        do {
            guard let activation = try licenseActivationStore.load() else {
                DebugLogger.log("license.activation.missing")
                showLicenseActivationWindow()
                return
            }

            DebugLogger.log("license.activation.loaded", [
                "instanceIDPresent": "\(activation.licenseKeyInstanceID.isEmpty == false)"
            ])

            let validatedActivation = try await licenseValidationService.validate(activation)
            try licenseActivationStore.save(validatedActivation)
            DebugLogger.log("license.validation.success")
            startMainApp()
        } catch {
            DebugLogger.log("license.validation.error", errorFields(error))
            licenseActivationStore.clear()
            DebugLogger.log("license.activation.cleared-current")
            showLicenseActivationWindow(
                initialErrorMessage: "Saved activation could not be verified. Enter your license key again."
            )
        }
    }

    private func showLicenseActivationWindow(initialErrorMessage: String? = nil) {
        DebugLogger.log("license.activation.window.show", [
            "hasInitialError": "\(initialErrorMessage != nil)"
        ])

        let activationController = LicenseActivationWindowController(
            validationService: licenseValidationService,
            activationStore: licenseActivationStore,
            initialErrorMessage: initialErrorMessage
        ) { [weak self] _ in
            DebugLogger.log("license.activation.completed")
            self?.licenseActivationController?.closeAfterActivation()
            self?.licenseActivationController = nil
            self?.startMainApp()
        }

        licenseActivationController = activationController
        activationController.showActivationWindow()
    }

    private func startMainApp() {
        guard coordinator == nil else {
            DebugLogger.log("app.start-main.skipped", ["reason": "coordinator-present"])
            return
        }

        DebugLogger.log("app.start-main")

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

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    private func errorFields(_ error: Error) -> [String: String] {
        let nsError = error as NSError
        return [
            "domain": nsError.domain,
            "code": "\(nsError.code)",
            "description": nsError.localizedDescription
        ]
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

    @objc private func quit() {
        DebugLogger.log("app.quit.request")
        NSApp.terminate(nil)
    }
}
