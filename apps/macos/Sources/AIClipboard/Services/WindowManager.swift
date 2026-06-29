import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowManager {
    private enum Metrics {
        static let islandAnimation = Animation.interactiveSpring(
            response: 0.38,
            dampingFraction: 0.8,
            blendDuration: 0
        )
        static let contentFadeDuration: TimeInterval = 0.06
        static let panelShrinkDelay: TimeInterval = 0.44
        static let pointerScreenPollInterval: TimeInterval = 0.18
    }

    private let pillViewModel: PillViewModel
    private let settings: PillSettings
    private let pillPanel: NSPanel
    private let overlayPanel: NSPanel
    private let overlayView = AnnotationOverlayView()
    private var collapseWorkItem: DispatchWorkItem?
    private var panelShrinkWorkItem: DispatchWorkItem?
    private var pointerScreenTimer: Timer?
    private var currentPillScreenID: CGDirectDisplayID?
    private var isPointerHoveringPillChrome = false
    private var settingsCancellable: AnyCancellable?

    init(pillViewModel: PillViewModel, settings: PillSettings) {
        self.pillViewModel = pillViewModel
        self.settings = settings

        pillPanel = NSPanel(
            contentRect: Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize(settings: settings), on: Self.screenContainingMouse()),
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

        configurePillPanel()
        configureOverlayPanel()
        observeSettings()
        startPointerScreenTracking()
    }

    func showPill() {
        panelShrinkWorkItem?.cancel()
        pillViewModel.isExpandedContentVisible = false
        pillViewModel.isCollapsedContentVisible = true
        pillViewModel.isExpanded = false
        currentPillScreenID = Self.screenContainingMouse()?.displayID
        setPillFrame(size: PillChromeMetrics.collapsedSize(settings: settings), display: true)
        pillPanel.orderFrontRegardless()
        pinPillToTopCenter()
    }

    func showOverlay(on screen: NSScreen, stroke: Stroke) {
        overlayView.stroke = stroke
        overlayPanel.setFrame(screen.frame, display: true)
        overlayPanel.orderFrontRegardless()
    }

    func updateOverlay(stroke: Stroke) {
        overlayView.stroke = stroke
    }

    func hideOverlay() {
        overlayPanel.orderOut(nil)
        overlayView.stroke = nil
    }

    private func configurePillPanel() {
        pillPanel.isOpaque = false
        pillPanel.backgroundColor = .clear
        pillPanel.hasShadow = false
        pillPanel.level = .statusBar
        pillPanel.isMovable = true
        pillPanel.isMovableByWindowBackground = false
        pillPanel.acceptsMouseMovedEvents = true
        pillPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        pillPanel.hidesOnDeactivate = false
        pillPanel.isReleasedWhenClosed = false
        pillPanel.contentView = NSHostingView(
            rootView: PillView(
                viewModel: pillViewModel,
                settings: settings,
                onHoverChanged: { [weak self] hovering in
                    self?.setPillHovering(hovering)
                }
            )
        )
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

    private func setPillFrame(size: CGSize, display: Bool) {
        let frame = Self.topCenterFrame(chromeSize: size, on: screenForCurrentPill())

        pillPanel.setFrame(frame, display: display, animate: false)
    }

    private func pinPillToTopCenter() {
        let expectedFrame = Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize(settings: settings), on: screenForCurrentPill())

        DispatchQueue.main.async { [weak self] in
            self?.pillPanel.setFrame(expectedFrame, display: true, animate: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, !self.pillViewModel.isExpanded else { return }
            self.pillPanel.setFrame(
                Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize(settings: self.settings), on: self.screenForCurrentPill()),
                display: true,
                animate: false
            )
        }
    }

    private func setPillHovering(_ hovering: Bool) {
        isPointerHoveringPillChrome = hovering
        collapseWorkItem?.cancel()
        panelShrinkWorkItem?.cancel()

        if hovering {
            guard settings.openOnHover else { return }

            pillViewModel.isCollapsedContentVisible = false
            pillViewModel.isExpandedContentVisible = true
            setPillFrame(size: PillChromeMetrics.expandedSize(settings: settings), display: true)
            pillPanel.orderFrontRegardless()

            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPointerHoveringPillChrome else { return }

                withAnimation(Metrics.islandAnimation) {
                    self.pillViewModel.isExpanded = true
                }
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

                    let shrinkWorkItem = DispatchWorkItem { [weak self] in
                        guard let self, !self.isPointerHoveringPillChrome, !self.pillViewModel.isExpanded else { return }
                        self.setPillFrame(size: PillChromeMetrics.collapsedSize(settings: self.settings), display: true)
                        self.pillViewModel.isCollapsedContentVisible = true
                    }
                    self.panelShrinkWorkItem = shrinkWorkItem
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Metrics.panelShrinkDelay,
                        execute: shrinkWorkItem
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

    private func observeSettings() {
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyPillSettings()
            }
        }
    }

    private func applyPillSettings() {
        let size = pillViewModel.isExpanded
            ? PillChromeMetrics.expandedSize(settings: settings)
            : PillChromeMetrics.collapsedSize(settings: settings)

        setPillFrame(size: size, display: true)
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
        guard let pointerScreen = Self.screenContainingMouse() else { return }
        let pointerScreenID = pointerScreen.displayID

        guard currentPillScreenID != pointerScreenID else { return }
        currentPillScreenID = pointerScreenID

        collapseWorkItem?.cancel()
        panelShrinkWorkItem?.cancel()
        pillViewModel.isExpandedContentVisible = false
        pillViewModel.isCollapsedContentVisible = true
        pillViewModel.isExpanded = false

        let targetFrame = Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize(settings: settings), on: pointerScreen)
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

    private static func topCenterFrame(chromeSize: CGSize, on screen: NSScreen?) -> CGRect {
        let screen = screen ?? screenContainingMouse() ?? NSScreen.screens.first ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let windowSize = PillChromeMetrics.windowSize(forChromeSize: chromeSize)

        return CGRect(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.maxY - chromeSize.height - PillChromeMetrics.topInset,
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
