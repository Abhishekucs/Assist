import AppKit
import Combine
import SwiftUI

private final class PillPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class WindowManager {
    private enum Metrics {
        static let islandAnimation = Animation.interactiveSpring(
            response: 0.38,
            dampingFraction: 0.8,
            blendDuration: 0
        )
        static let contentRevealDelay: TimeInterval = 0.08
        static let contentFadeDuration: TimeInterval = 0.04
        static let collapsedRevealDelay: TimeInterval = 0.32
        static let pointerScreenPollInterval: TimeInterval = 0.18
        static let editorResizeDuration: TimeInterval = 0.24
    }

    private let pillViewModel: PillViewModel
    private let screenshotEditorViewModel: ScreenshotEditorViewModel
    private let settings: PillSettings
    private let pillPanel: NSPanel
    private let overlayPanel: NSPanel
    private let screenshotEditorPanel: NSPanel
    private let overlayView = AnnotationOverlayView()
    private var collapseWorkItem: DispatchWorkItem?
    private var contentRevealWorkItem: DispatchWorkItem?
    private var collapsedRevealWorkItem: DispatchWorkItem?
    private var pointerScreenTimer: Timer?
    private var currentPillScreenID: CGDirectDisplayID?
    private var screenshotEditorReturnScreenID: CGDirectDisplayID?
    private var isResizingScreenshotEditor = false
    private var isPointerHoveringPillChrome = false
    private var isDraggingFromPill = false
    private var settingsCancellable: AnyCancellable?

    init(
        pillViewModel: PillViewModel,
        screenshotEditorViewModel: ScreenshotEditorViewModel,
        settings: PillSettings
    ) {
        self.pillViewModel = pillViewModel
        self.screenshotEditorViewModel = screenshotEditorViewModel
        self.settings = settings

        pillPanel = PillPanel(
            contentRect: Self.topCenterFrame(
                windowSize: PillChromeMetrics.expandedSize(settings: settings),
                on: Self.screenContainingMouse()
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlayPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        screenshotEditorPanel = PillPanel(
            contentRect: CGRect(origin: .zero, size: ScreenshotEditorMetrics.preferredSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePillPanel()
        configureOverlayPanel()
        configureScreenshotEditorPanel()
        observeSettings()
        startPointerScreenTracking()
    }

    func showPill() {
        contentRevealWorkItem?.cancel()
        collapsedRevealWorkItem?.cancel()
        pillViewModel.isExpandedContentVisible = false
        pillViewModel.isCollapsedContentVisible = true
        pillViewModel.isExpanded = false
        currentPillScreenID = Self.screenContainingMouse()?.displayID
        setPillFrame(display: true)
        pillPanel.orderFrontRegardless()
        pinPillToTopCenter()
    }

    func showOverlay(on screen: NSScreen, stroke: Stroke) {
        overlayView.begin(stroke: stroke)
        overlayPanel.setFrame(screen.frame, display: true)
        overlayPanel.orderFrontRegardless()
    }

    func updateOverlay(stroke: Stroke) {
        overlayView.update(stroke: stroke)
    }

    func hideOverlay() {
        overlayPanel.orderOut(nil)
        overlayView.clear()
    }

    func showScreenshotEditor(on capturedScreen: NSScreen) {
        collapseWorkItem?.cancel()
        contentRevealWorkItem?.cancel()
        collapsedRevealWorkItem?.cancel()

        if !screenshotEditorPanel.isVisible, !settings.followPointerDisplay {
            screenshotEditorReturnScreenID = screenForCurrentPill()?.displayID
        }
        // The editor belongs to the capture, so always present it on the captured display.
        // A fixed pill is restored to its prior display when the short-lived editor closes.
        currentPillScreenID = capturedScreen.displayID

        isPointerHoveringPillChrome = false
        isDraggingFromPill = false
        pillViewModel.isExpandedContentVisible = false
        pillViewModel.isCollapsedContentVisible = true
        pillViewModel.isExpanded = false

        setPillFrame(display: true)
        pillPanel.orderFrontRegardless()
        positionScreenshotEditor()
        screenshotEditorPanel.orderFrontRegardless()
        screenshotEditorPanel.contentView?.layoutSubtreeIfNeeded()
        screenshotEditorPanel.displayIfNeeded()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // The system shadow follows the card's alpha, so refresh it once the content is drawn.
            self.screenshotEditorPanel.invalidateShadow()
            self.syncScreenshotEditorHover()
            DebugLogger.log("screenshot-editor.window-presented", [
                "frame": DebugLogger.describe(self.screenshotEditorPanel.frame),
                "isVisible": "\(self.screenshotEditorPanel.isVisible)",
                "screenID": self.screenForCurrentPill().map { "\($0.displayID)" } ?? "unknown"
            ])
        }
    }

    func hideScreenshotEditor() {
        isResizingScreenshotEditor = false
        screenshotEditorPanel.orderOut(nil)

        if !settings.followPointerDisplay, let screenshotEditorReturnScreenID {
            currentPillScreenID = screenshotEditorReturnScreenID
            setPillFrame(display: true)
            pillPanel.orderFrontRegardless()
        }
        screenshotEditorReturnScreenID = nil
    }

    /// Resizes the editor card in place when the user expands or shrinks the preview.
    func screenshotEditorExpansionChanged() {
        guard screenshotEditorPanel.isVisible else { return }
        isResizingScreenshotEditor = true
        positionScreenshotEditor(animated: true) { [weak self] in
            guard let self else { return }
            self.isResizingScreenshotEditor = false
            self.syncScreenshotEditorHover()
        }
    }

    func restorePillToFront(reason: String) {
        contentRevealWorkItem?.cancel()
        collapsedRevealWorkItem?.cancel()
        currentPillScreenID = screenForCurrentPill()?.displayID
        setPillFrame(display: true)
        pillPanel.orderFrontRegardless()
        pinPillToTopCenter()
        if screenshotEditorPanel.isVisible {
            positionScreenshotEditor()
            screenshotEditorPanel.orderFrontRegardless()
        }
        DebugLogger.log("pill.restore-to-front", [
            "reason": reason,
            "screenID": currentPillScreenID.map { "\($0)" } ?? "unknown"
        ])
    }

    private func configurePillPanel() {
        pillPanel.isOpaque = false
        pillPanel.backgroundColor = .clear
        pillPanel.hasShadow = false
        pillPanel.level = .statusBar
        pillPanel.isMovable = true
        pillPanel.isMovableByWindowBackground = false
        pillPanel.becomesKeyOnlyIfNeeded = true
        pillPanel.acceptsMouseMovedEvents = true
        pillPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        pillPanel.hidesOnDeactivate = false
        pillPanel.isReleasedWhenClosed = false
        let hostingView = PillHostingView(
            rootView: PillView(
                viewModel: pillViewModel,
                settings: settings,
                onHoverChanged: { [weak self] hovering in
                    self?.setPillHovering(hovering)
                },
                onIslandDragChanged: { [weak self] dragging in
                    self?.setPillDragging(dragging)
                }
            )
        )
        hostingView.visibleChromeRectProvider = { [weak self, weak hostingView] in
            guard let self, let hostingView else { return .zero }

            let chromeSize = self.pillViewModel.isExpanded
                ? PillChromeMetrics.expandedSize(settings: self.settings)
                : PillChromeMetrics.collapsedSize(settings: self.settings)
            let bounds = hostingView.bounds

            return CGRect(
                x: bounds.midX - chromeSize.width / 2,
                y: bounds.maxY - chromeSize.height,
                width: chromeSize.width,
                height: chromeSize.height
            )
        }
        pillPanel.contentView = hostingView
    }

    private func configureOverlayPanel() {
        overlayPanel.isOpaque = false
        overlayPanel.backgroundColor = .clear
        overlayPanel.hasShadow = false
        overlayPanel.level = .screenSaver
        overlayPanel.ignoresMouseEvents = true
        overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        overlayPanel.hidesOnDeactivate = false
        overlayPanel.isReleasedWhenClosed = false
        overlayPanel.contentView = overlayView
    }

    private func configureScreenshotEditorPanel() {
        screenshotEditorPanel.isOpaque = false
        screenshotEditorPanel.backgroundColor = .clear
        screenshotEditorPanel.hasShadow = true
        screenshotEditorPanel.level = .statusBar
        screenshotEditorPanel.isMovable = false
        screenshotEditorPanel.becomesKeyOnlyIfNeeded = false
        screenshotEditorPanel.acceptsMouseMovedEvents = true
        screenshotEditorPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        screenshotEditorPanel.hidesOnDeactivate = false
        screenshotEditorPanel.isReleasedWhenClosed = false

        let hostingView = ScreenshotEditorHostingView(
            rootView: ScreenshotQuickEditorView(viewModel: screenshotEditorViewModel)
        )
        hostingView.onHoverChanged = { [weak self, weak screenshotEditorViewModel] hovering in
            guard self?.isResizingScreenshotEditor != true else { return }
            screenshotEditorViewModel?.pointerChanged(isInside: hovering)
        }
        screenshotEditorPanel.contentView = hostingView
    }

    private func setPillFrame(display: Bool) {
        let frame = Self.topCenterFrame(
            windowSize: PillChromeMetrics.expandedSize(settings: settings),
            on: screenForCurrentPill()
        )

        pillPanel.setFrame(frame, display: display, animate: false)
    }

    private func pinPillToTopCenter() {
        let expectedFrame = Self.topCenterFrame(
            windowSize: PillChromeMetrics.expandedSize(settings: settings),
            on: screenForCurrentPill()
        )

        DispatchQueue.main.async { [weak self] in
            self?.pillPanel.setFrame(expectedFrame, display: true, animate: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, !self.pillViewModel.isExpanded else { return }
            self.pillPanel.setFrame(
                Self.topCenterFrame(
                    windowSize: PillChromeMetrics.expandedSize(settings: self.settings),
                    on: self.screenForCurrentPill()
                ),
                display: true,
                animate: false
            )
        }
    }

    private func setPillHovering(_ hovering: Bool) {
        isPointerHoveringPillChrome = hovering
        guard !screenshotEditorPanel.isVisible else { return }
        collapseWorkItem?.cancel()
        contentRevealWorkItem?.cancel()
        collapsedRevealWorkItem?.cancel()

        guard !isDraggingFromPill else { return }

        if hovering {
            guard settings.openOnHover else { return }

            pillViewModel.willShowHistory()
            pillViewModel.isCollapsedContentVisible = false
            setPillFrame(display: true)
            pillPanel.orderFrontRegardless()

            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPointerHoveringPillChrome else { return }

                withAnimation(Metrics.islandAnimation) {
                    self.pillViewModel.isExpanded = true
                }

                let revealWorkItem = DispatchWorkItem { [weak self] in
                    guard let self, self.isPointerHoveringPillChrome, self.pillViewModel.isExpanded else { return }
                    self.pillViewModel.isExpandedContentVisible = true
                }
                self.contentRevealWorkItem = revealWorkItem
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Metrics.contentRevealDelay,
                    execute: revealWorkItem
                )
            }
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            if !self.isPointerHoveringPillChrome {
                self.pillViewModel.isExpandedContentVisible = false

                let collapseFrameWorkItem = DispatchWorkItem { [weak self] in
                    guard let self, self.pillViewModel.isExpanded else { return }

                    guard !self.isPointerHoveringPillChrome else {
                        self.pillViewModel.isExpandedContentVisible = true
                        return
                    }

                    withAnimation(Metrics.islandAnimation) {
                        self.pillViewModel.isExpanded = false
                    }

                    let revealCollapsedWorkItem = DispatchWorkItem { [weak self] in
                        guard let self, !self.isPointerHoveringPillChrome, !self.pillViewModel.isExpanded else { return }
                        self.pillViewModel.isCollapsedContentVisible = true
                    }
                    self.collapsedRevealWorkItem = revealCollapsedWorkItem
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Metrics.collapsedRevealDelay,
                        execute: revealCollapsedWorkItem
                    )
                }
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Metrics.contentFadeDuration,
                    execute: collapseFrameWorkItem
                )
            }
        }

        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
    }

    private func setPillDragging(_ dragging: Bool) {
        guard isDraggingFromPill != dragging else { return }

        isDraggingFromPill = dragging
        collapseWorkItem?.cancel()
        contentRevealWorkItem?.cancel()
        collapsedRevealWorkItem?.cancel()

        if dragging {
            isPointerHoveringPillChrome = true
            pillViewModel.willShowHistory()
            pillViewModel.isCollapsedContentVisible = false
            pillViewModel.isExpanded = true
            pillViewModel.isExpandedContentVisible = true
            setPillFrame(display: true)
            pillPanel.orderFrontRegardless()
            DebugLogger.log("pill.drag.start")
            return
        }

        isPointerHoveringPillChrome = isMouseInsideVisiblePillChrome()
        DebugLogger.log("pill.drag.end", [
            "hovering": "\(isPointerHoveringPillChrome)"
        ])

        if !isPointerHoveringPillChrome {
            setPillHovering(false)
        }
    }

    private func isMouseInsideVisiblePillChrome() -> Bool {
        guard let hostingView = pillPanel.contentView as? PillHostingView else {
            return false
        }

        let point = hostingView.convert(pillPanel.mouseLocationOutsideOfEventStream, from: nil)
        guard let chromeRect = hostingView.visibleChromeRectProvider?() else {
            return hostingView.bounds.contains(point)
        }

        return chromeRect.insetBy(dx: -2, dy: -2).contains(point)
    }

    private func observeSettings() {
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyPillSettings()
            }
        }
    }

    private func applyPillSettings() {
        setPillFrame(display: true)
        if screenshotEditorPanel.isVisible {
            positionScreenshotEditor()
        }
    }

    private func startPointerScreenTracking() {
        pointerScreenTimer?.invalidate()
        let timer = Timer(timeInterval: Metrics.pointerScreenPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncPillToPointerScreen()
            }
        }
        pointerScreenTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func syncPillToPointerScreen() {
        guard settings.followPointerDisplay else { return }
        guard !screenshotEditorPanel.isVisible else { return }
        guard !isDraggingFromPill else { return }
        guard let pointerScreen = Self.screenContainingMouse() else { return }
        let pointerScreenID = pointerScreen.displayID

        guard currentPillScreenID != pointerScreenID else { return }
        currentPillScreenID = pointerScreenID

        collapseWorkItem?.cancel()
        contentRevealWorkItem?.cancel()
        collapsedRevealWorkItem?.cancel()
        pillViewModel.isExpandedContentVisible = false
        pillViewModel.isCollapsedContentVisible = true
        pillViewModel.isExpanded = false

        let targetFrame = Self.topCenterFrame(
            windowSize: PillChromeMetrics.expandedSize(settings: settings),
            on: pointerScreen
        )
        pillPanel.setFrame(targetFrame, display: true, animate: false)
        pillPanel.orderFrontRegardless()
    }

    private func screenForCurrentPill() -> NSScreen? {
        if let currentPillScreenID,
           let screen = NSScreen.screens.first(where: { $0.displayID == currentPillScreenID }) {
            return screen
        }

        return Self.screenContainingMouse() ?? NSScreen.screens.first ?? NSScreen.main
    }

    private func positionScreenshotEditor(
        animated: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        guard let screen = screenForCurrentPill() else { return }
        let collapsedSize = PillChromeMetrics.collapsedSize(settings: settings)
        let pillChromeFrame = CGRect(
            x: pillPanel.frame.midX - collapsedSize.width / 2,
            y: pillPanel.frame.maxY - collapsedSize.height,
            width: collapsedSize.width,
            height: collapsedSize.height
        )
        let frame = ScreenshotEditorMetrics.frame(
            below: pillChromeFrame,
            on: screen.frame,
            expanded: screenshotEditorViewModel.isExpanded,
            imageAspectRatio: screenshotEditorViewModel.imageAspectRatio
        )

        guard animated else {
            screenshotEditorPanel.setFrame(frame, display: true, animate: false)
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Metrics.editorResizeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            screenshotEditorPanel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self, weak screenshotEditorPanel] in
            // AppKit runs this on the main thread once the resize settles.
            MainActor.assumeIsolated {
                // The system shadow keeps the pre-resize outline until it is invalidated.
                screenshotEditorPanel?.invalidateShadow()
                guard self != nil else { return }
                completion?()
            }
        }
    }

    private func syncScreenshotEditorHover() {
        guard screenshotEditorPanel.isVisible,
              let contentView = screenshotEditorPanel.contentView else { return }
        let point = contentView.convert(
            screenshotEditorPanel.mouseLocationOutsideOfEventStream,
            from: nil
        )
        screenshotEditorViewModel.pointerChanged(isInside: contentView.bounds.contains(point))
    }

    private static func topCenterFrame(windowSize: CGSize, on screen: NSScreen?) -> CGRect {
        let screen = screen ?? screenContainingMouse() ?? NSScreen.screens.first ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        return CGRect(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.maxY - windowSize.height - PillChromeMetrics.topInset,
            width: windowSize.width,
            height: windowSize.height
        )
    }

    private static func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = deviceDescription[key] as? NSNumber {
            return number.uint32Value
        }

        return CGMainDisplayID()
    }
}
