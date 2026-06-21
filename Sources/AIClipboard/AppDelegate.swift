import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = CaptureStore()
        let pillViewModel = PillViewModel()
        let windowManager = WindowManager(pillViewModel: pillViewModel)
        let coordinator = AppCoordinator(
            windowManager: windowManager,
            captureService: CaptureService(),
            store: store,
            analysisService: VisionAnalysisService(),
            pillViewModel: pillViewModel
        )

        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}
