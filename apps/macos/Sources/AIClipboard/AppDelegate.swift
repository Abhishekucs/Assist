import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var controlPanelController: ControlPanelWindowController?
    private var pillViewModel: PillViewModel?
    private var statusItem: NSStatusItem?
    private var settingsCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = CaptureStore()
        let settings = PillSettings()
        let pillViewModel = PillViewModel(settings: settings)
        let windowManager = WindowManager(pillViewModel: pillViewModel, settings: settings)
        let controlPanelController = ControlPanelWindowController(settings: settings, pillViewModel: pillViewModel)
        let coordinator = AppCoordinator(
            windowManager: windowManager,
            captureService: CaptureService(),
            store: store,
            analysisService: VisionAnalysisService(),
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    private func configureStatusItem(settings: PillSettings) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: AppIdentity.name
        )
        item.button?.toolTip = AppIdentity.name

        let menu = NSMenu()
        menu.addItem(menuItem(title: "Open Controls", action: #selector(openControls), keyEquivalent: ","))
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
