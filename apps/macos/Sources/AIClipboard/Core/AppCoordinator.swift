import AppKit

@MainActor
final class AppCoordinator: ControlGestureMonitorDelegate, ClipboardTextMonitorDelegate {
    private let windowManager: WindowManager
    private let captureService: CaptureService
    private let store: CaptureStore
    private let pillViewModel: PillViewModel
    private let monitor = ControlGestureMonitor()
    private let clipboardMonitor = ClipboardTextMonitor()

    private var activeScreen: NSScreen?
    private var activeStroke: Stroke?
    private var isCapturing = false
    private var annotationSessionID: UUID?
    private var debugOverlayWorkItems: [DispatchWorkItem] = []

    init(
        windowManager: WindowManager,
        captureService: CaptureService,
        store: CaptureStore,
        pillViewModel: PillViewModel
    ) {
        self.windowManager = windowManager
        self.captureService = captureService
        self.store = store
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
        pillViewModel.onWillWritePasteboard = { [weak self] in
            self?.clipboardMonitor.ignoreNextPasteboardWrite()
        }
        pillViewModel.onDeleteHistoryItem = { [weak self] item in
            self?.deleteHistoryItem(item)
        }
        pillViewModel.onWillShowHistory = { [weak self] in
            self?.syncHistoryFromStore()
        }

        syncHistoryFromStore()
        pillViewModel.clearCaptureIssue()

        windowManager.showPill()

        monitor.delegate = self
        clipboardMonitor.delegate = self
        clipboardMonitor.start()
        do {
            try monitor.start()
        } catch {
            pillViewModel.showCaptureIssue(.inputMonitoring(detail: error.localizedDescription))
        }
    }

    func stop() {
        DebugLogger.log("app.stop")
        monitor.stop()
        clipboardMonitor.stop()
    }

    func clipboardTextMonitor(_ monitor: ClipboardTextMonitor, didCopy text: String) {
        do {
            let item = try store.save(text: text)
            pillViewModel.insertTextItem(item)
            pillViewModel.statusText = "Copied text"
            pillViewModel.diagnosticMessage = "Captured copied text"
            pillViewModel.showCopyFeedback(badge: "Copied", preview: item.preview)
            DebugLogger.log("clipboard.text.saved", [
                "id": item.id.uuidString,
                "characters": "\(item.text.count)"
            ])
        } catch {
            DebugLogger.log("clipboard.text.save.error", errorFields(error))
        }
    }

    private func deleteHistoryItem(_ item: ClipboardHistoryItem) {
        do {
            switch item {
            case let .screenshot(capture):
                try store.delete(item: capture)
            case let .text(textClip):
                try store.delete(textItem: textClip)
            }

            pillViewModel.remove(item)
            pillViewModel.statusText = "Deleted"
            pillViewModel.diagnosticMessage = "Deleted item from history"
            DebugLogger.log("history.item.deleted", ["id": item.id.uuidString])
        } catch {
            DebugLogger.log("history.item.delete.error", errorFields(error))
            pillViewModel.statusText = "Delete failed"
            pillViewModel.diagnosticMessage = error.localizedDescription
        }
    }

    private func syncHistoryFromStore() {
        let screenshots = store.loadItems()
        let textClips = store.loadTextItems()
        let previousIDs = Set(pillViewModel.historyItems.map(\.id))
        let nextIDs = Set((screenshots.map(ClipboardHistoryItem.screenshot) + textClips.map(ClipboardHistoryItem.text)).map(\.id))

        pillViewModel.replaceHistory(screenshots: screenshots, textClips: textClips)

        if previousIDs != nextIDs {
            DebugLogger.log("history.synced", [
                "screenshots": "\(screenshots.count)",
                "textClips": "\(textClips.count)"
            ])
        }
    }

    func annotationGestureDidBegin(at globalPoint: CGPoint) {
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

    func annotationGestureDidMove(to globalPoint: CGPoint) {
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

    func annotationGestureDidEnd(at globalPoint: CGPoint) {
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
                saveCapture(image: finalImage, statusText: "Saving capture...")
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
                saveCapture(image: image, statusText: "Saving screenshot...")
            } catch {
                DebugLogger.log("clean-screenshot.capture.error", errorFields(error))
                handleCaptureError(error)
            }
        }
    }

    private func saveCapture(image: NSImage, statusText: String) {
        pillViewModel.statusText = statusText
        pillViewModel.isBusy = true

        do {
            pillViewModel.clearCaptureIssue()
            let item = try store.save(image: image, context: .saved)
            insertOrUpdate(item)
            pillViewModel.diagnosticMessage = "Saved \(URL(fileURLWithPath: item.imagePath).lastPathComponent)"
            DebugLogger.log("capture.saved", [
                "id": item.id.uuidString,
                "imagePath": item.imagePath
            ])
            pillViewModel.statusText = "Ready"
            pillViewModel.isBusy = false
            pillViewModel.showCopyFeedback(badge: "Saved", preview: "Screenshot")
        } catch {
            DebugLogger.log("capture.save.error", errorFields(error))
            pillViewModel.statusText = error.localizedDescription
            pillViewModel.isBusy = false
            pillViewModel.showCaptureIssue(.captureFailed(detail: error.localizedDescription))
        }
    }

    private func handleCaptureError(_ error: Error) {
        DebugLogger.log("capture.handle-error", errorFields(error).merging([
            "screenPreflight": "\(CGPreflightScreenCaptureAccess())"
        ]) { current, _ in current })

        let nsError = error as NSError
        pillViewModel.clearCaptureIssue()

        if !CGPreflightScreenCaptureAccess() || isScreenCaptureKitTCCDenial(nsError) {
            DebugLogger.log("capture.handle-error.tcc-denied", [
                "description": nsError.localizedDescription
            ])
            pillViewModel.showCaptureIssue(.screenRecording(detail: nsError.localizedDescription))
            return
        }

        DebugLogger.log("capture.handle-error.status-only", [
            "description": nsError.localizedDescription
        ])
        pillViewModel.showCaptureIssue(.captureFailed(detail: nsError.localizedDescription))
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
        pillViewModel.replaceScreenshot(item)
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
