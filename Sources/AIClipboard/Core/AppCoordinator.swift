import AppKit

@MainActor
final class AppCoordinator: ControlGestureMonitorDelegate {
    private let windowManager: WindowManager
    private let captureService: CaptureService
    private let store: CaptureStore
    private let analysisService: VisionAnalysisService
    private let pillViewModel: PillViewModel
    private let monitor = ControlGestureMonitor()

    private var activeScreen: NSScreen?
    private var activeStroke: Stroke?
    private var isCapturing = false
    private var annotationSessionID: UUID?
    private var debugOverlayWorkItems: [DispatchWorkItem] = []

    init(
        windowManager: WindowManager,
        captureService: CaptureService,
        store: CaptureStore,
        analysisService: VisionAnalysisService,
        pillViewModel: PillViewModel
    ) {
        self.windowManager = windowManager
        self.captureService = captureService
        self.store = store
        self.analysisService = analysisService
        self.pillViewModel = pillViewModel
    }

    func start() {
        DebugLogger.log("app.start", [
            "bundle": Bundle.main.bundleIdentifier ?? "unknown",
            "executable": Bundle.main.executablePath ?? "unknown",
            "screenPreflight": "\(CGPreflightScreenCaptureAccess())",
            "accessibility": "\(AXIsProcessTrusted())"
        ])
        logScreens()

        pillViewModel.onTestScreenshot = { [weak self] in
            self?.runDebugScreenshotTest()
        }
        pillViewModel.onTestOverlay = { [weak self] in
            self?.runDebugOverlayTest()
        }

        pillViewModel.items = store.loadItems()
        pillViewModel.latestItem = pillViewModel.items.first
        pillViewModel.cacheThumbnails(for: pillViewModel.items)
        pillViewModel.clearCaptureIssue()

        windowManager.showPill()

        monitor.delegate = self
        do {
            try monitor.start()
        } catch {
            pillViewModel.statusText = error.localizedDescription
        }
    }

    func stop() {
        DebugLogger.log("app.stop")
        monitor.stop()
    }

    func controlGestureDidBegin(at globalPoint: CGPoint) {
        guard !isCapturing else { return }

        guard let screen = NSScreen.screen(containing: globalPoint) ?? NSScreen.main else {
            return
        }

        DebugLogger.log("annotation.begin.request", [
            "point": DebugLogger.describe(globalPoint),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        let sessionID = UUID()
        annotationSessionID = sessionID
        isCapturing = true
        pillViewModel.isBusy = true
        pillViewModel.statusText = "Annotating..."

        let startPoint = screen.localTopLeftPoint(forGlobalPoint: globalPoint)
        let stroke = Stroke(points: [startPoint], colorHex: "#FF3B30", width: 5)

        activeScreen = screen
        activeStroke = stroke

        windowManager.showOverlay(on: screen, stroke: stroke)
        DebugLogger.log("annotation.begin.ready", [
            "session": sessionID.uuidString,
            "startPoint": DebugLogger.describe(startPoint)
        ])
    }

    func controlGestureDidMove(to globalPoint: CGPoint) {
        guard isCapturing, let screen = activeScreen, var stroke = activeStroke else { return }

        let point = screen.localTopLeftPoint(forGlobalPoint: globalPoint)
        guard stroke.points.last.map({ $0.distance(to: point) > 1.5 }) ?? true else { return }

        stroke.points.append(point)
        activeStroke = stroke
        windowManager.updateOverlay(stroke: stroke)
        if stroke.points.count % 20 == 0 {
            DebugLogger.log("annotation.move", [
                "points": "\(stroke.points.count)",
                "point": DebugLogger.describe(point)
            ])
        }
    }

    func controlGestureDidEnd(at globalPoint: CGPoint) {
        guard isCapturing, let screen = activeScreen, var stroke = activeStroke else {
            DebugLogger.log("annotation.end.no-active-stroke", [
                "point": DebugLogger.describe(globalPoint)
            ])
            resetCaptureState()
            return
        }

        let point = screen.localTopLeftPoint(forGlobalPoint: globalPoint)
        if stroke.points.last != point {
            stroke.points.append(point)
        }

        windowManager.hideOverlay()
        pillViewModel.isBusy = true
        pillViewModel.statusText = "Saving capture..."
        DebugLogger.log("annotation.end", [
            "points": "\(stroke.points.count)",
            "point": DebugLogger.describe(globalPoint),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        let sessionID = annotationSessionID
        Task {
            do {
                let captured = try await captureService.capture(screen: screen)
                guard self.annotationSessionID == sessionID else { return }
                let finalImage = try captureService.composite(captured: captured, stroke: stroke)
                saveAndAnalyze(image: finalImage, statusText: "Saving capture...")
                resetCaptureState()
            } catch {
                guard self.annotationSessionID == sessionID else { return }
                DebugLogger.log("annotation.capture-or-composite.error", errorFields(error))
                handleCaptureError(error)
                resetCaptureState()
            }
        }
    }

    func controlOptionScreenshotRequested(at globalPoint: CGPoint) {
        DebugLogger.log("clean-screenshot.shortcut", [
            "point": DebugLogger.describe(globalPoint)
        ])
        windowManager.hideOverlay()
        resetCaptureState()
        saveCleanScreenshot(at: globalPoint)
    }

    private func saveCleanScreenshot(at globalPoint: CGPoint) {
        guard let screen = NSScreen.screen(containing: globalPoint) ?? NSScreen.main else {
            return
        }

        pillViewModel.statusText = "Saving screenshot..."
        pillViewModel.isBusy = true
        DebugLogger.log("clean-screenshot.capture.request", [
            "point": DebugLogger.describe(globalPoint),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        Task {
            do {
                let captured = try await captureService.capture(screen: screen)
                let image = captureService.image(from: captured)
                saveAndAnalyze(image: image, statusText: "Saving screenshot...")
            } catch {
                DebugLogger.log("clean-screenshot.capture.error", errorFields(error))
                handleCaptureError(error)
            }
        }
    }

    private func saveAndAnalyze(image: NSImage, statusText: String) {
        pillViewModel.statusText = statusText
        pillViewModel.isBusy = true

        do {
            pillViewModel.clearCaptureIssue()
            var item = try store.save(image: image, context: .pending)
            insertOrUpdate(item)
            pillViewModel.diagnosticMessage = "Saved \(URL(fileURLWithPath: item.imagePath).lastPathComponent)"
            DebugLogger.log("capture.saved", [
                "id": item.id.uuidString,
                "imagePath": item.imagePath
            ])

            Task {
                let context = await analysisService.analyze(imageURL: URL(fileURLWithPath: item.imagePath))
                item.context = context
                self.store.update(item: item)
                self.insertOrUpdate(item)
                self.pillViewModel.statusText = "Ready"
                self.pillViewModel.isBusy = false
            }
        } catch {
            DebugLogger.log("capture.save.error", errorFields(error))
            pillViewModel.statusText = error.localizedDescription
            pillViewModel.isBusy = false
        }
    }

    private func handleCaptureError(_ error: Error) {
        DebugLogger.log("capture.handle-error", errorFields(error).merging([
            "screenPreflight": "\(CGPreflightScreenCaptureAccess())"
        ]) { current, _ in current })

        let nsError = error as NSError
        pillViewModel.clearCaptureIssue()

        if isScreenCaptureKitTCCDenial(nsError) {
            DebugLogger.log("capture.handle-error.tcc-denied", [
                "description": nsError.localizedDescription
            ])
            pillViewModel.statusText = "Capture fallback"
            pillViewModel.isBusy = false
            pillViewModel.diagnosticMessage = "ScreenCaptureKit was denied; fallback capture will be used."
            return
        }

        DebugLogger.log("capture.handle-error.status-only", [
            "description": nsError.localizedDescription
        ])
        pillViewModel.statusText = "Capture failed"
        pillViewModel.isBusy = false
        pillViewModel.diagnosticMessage = nsError.localizedDescription
    }

    private func isScreenCaptureKitTCCDenial(_ error: NSError) -> Bool {
        error.domain == "com.apple.ScreenCaptureKit.SCStreamErrorDomain"
            && error.code == -3801
    }

    private func runDebugScreenshotTest() {
        let point = NSEvent.mouseLocation
        DebugLogger.log("debug.screenshot-test.clicked", [
            "point": DebugLogger.describe(point),
            "screenPreflight": "\(CGPreflightScreenCaptureAccess())"
        ])
        saveCleanScreenshot(at: point)
    }

    private func runDebugOverlayTest() {
        cancelDebugOverlayTest()

        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screen(containing: point) ?? NSScreen.main else {
            pillViewModel.diagnosticMessage = "No screen found for overlay test."
            DebugLogger.log("debug.overlay-test.no-screen", ["point": DebugLogger.describe(point)])
            return
        }

        let start = screen.localTopLeftPoint(forGlobalPoint: point)
        var stroke = Stroke(points: [start], colorHex: "#FF3B30", width: 6)

        pillViewModel.statusText = "Overlay test"
        pillViewModel.isBusy = true
        pillViewModel.diagnosticMessage = "Showing overlay test path..."
        DebugLogger.log("debug.overlay-test.start", [
            "point": DebugLogger.describe(point),
            "localPoint": DebugLogger.describe(start),
            "screenFrame": DebugLogger.describe(screen.frame)
        ])

        windowManager.showOverlay(on: screen, stroke: stroke)

        for index in 1...24 {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let nextPoint = CGPoint(
                    x: start.x + CGFloat(index * 12),
                    y: start.y + sin(CGFloat(index) * 0.45) * 38
                )
                stroke.points.append(nextPoint)
                self.windowManager.updateOverlay(stroke: stroke)
            }
            debugOverlayWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.025, execute: workItem)
        }

        let hideWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.windowManager.hideOverlay()
            self.pillViewModel.statusText = "Ready"
            self.pillViewModel.isBusy = false
            self.pillViewModel.diagnosticMessage = "Overlay test completed. Check if red path appeared."
            DebugLogger.log("debug.overlay-test.end", ["points": "\(stroke.points.count)"])
            self.debugOverlayWorkItems.removeAll()
        }
        debugOverlayWorkItems.append(hideWorkItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15, execute: hideWorkItem)
    }

    private func cancelDebugOverlayTest() {
        for workItem in debugOverlayWorkItems {
            workItem.cancel()
        }
        debugOverlayWorkItems.removeAll()
        windowManager.hideOverlay()
        pillViewModel.isBusy = false
    }

    private func errorFields(_ error: Error) -> [String: String] {
        let nsError = error as NSError
        return [
            "domain": nsError.domain,
            "code": "\(nsError.code)",
            "description": nsError.localizedDescription
        ]
    }

    private func logScreens() {
        for (index, screen) in NSScreen.screens.enumerated() {
            DebugLogger.log("screen.available", [
                "index": "\(index)",
                "frame": DebugLogger.describe(screen.frame),
                "visible": DebugLogger.describe(screen.visibleFrame),
                "scale": "\(screen.backingScaleFactor)"
            ])
        }
    }

    private func insertOrUpdate(_ item: CaptureItem) {
        var items = pillViewModel.items.filter { $0.id != item.id }
        items.insert(item, at: 0)
        pillViewModel.items = items
        pillViewModel.latestItem = item
        pillViewModel.cacheThumbnails(for: items)
    }

    private func resetCaptureState() {
        isCapturing = false
        activeScreen = nil
        activeStroke = nil
        annotationSessionID = nil
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

private extension NSScreen {
    static func screen(containing point: CGPoint) -> NSScreen? {
        screens.first { $0.frame.contains(point) }
    }

    func localTopLeftPoint(forGlobalPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - frame.minX,
            y: frame.maxY - point.y
        )
    }
}
