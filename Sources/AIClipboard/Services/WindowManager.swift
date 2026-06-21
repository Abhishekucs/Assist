import AppKit
import SwiftUI

@MainActor
final class WindowManager {
    private enum Metrics {
        static let islandAnimation = Animation.interactiveSpring(
            response: 0.38,
            dampingFraction: 0.8,
            blendDuration: 0
        )
        static let contentRevealDelay: TimeInterval = 0.3
        static let contentFadeDuration: TimeInterval = 0.08
        static let panelShrinkDelay: TimeInterval = 0.52
        static let pointerScreenPollInterval: TimeInterval = 0.18
    }

    private let pillViewModel: PillViewModel
    private let pillPanel: NSPanel
    private let overlayPanel: NSPanel
    private let overlayView = AnnotationOverlayView()
    private var collapseWorkItem: DispatchWorkItem?
    private var contentRevealWorkItem: DispatchWorkItem?
    private var panelShrinkWorkItem: DispatchWorkItem?
    private var pointerScreenTimer: Timer?
    private var currentPillScreenID: CGDirectDisplayID?
    private var isPointerHoveringPillChrome = false

    init(pillViewModel: PillViewModel) {
        self.pillViewModel = pillViewModel

        pillPanel = NSPanel(
            contentRect: Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize, on: Self.screenContainingMouse()),
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
        startPointerScreenTracking()
    }

    func showPill() {
        panelShrinkWorkItem?.cancel()
        pillViewModel.isExpandedContentVisible = false
        pillViewModel.isCollapsedContentVisible = true
        pillViewModel.isExpanded = false
        currentPillScreenID = Self.screenContainingMouse()?.displayID
        setPillFrame(size: PillChromeMetrics.collapsedSize, display: true)
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
        let expectedFrame = Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize, on: screenForCurrentPill())

        DispatchQueue.main.async { [weak self] in
            self?.pillPanel.setFrame(expectedFrame, display: true, animate: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, !self.pillViewModel.isExpanded else { return }
            self.pillPanel.setFrame(Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize, on: self.screenForCurrentPill()), display: true, animate: false)
        }
    }

    private func setPillHovering(_ hovering: Bool) {
        isPointerHoveringPillChrome = hovering
        collapseWorkItem?.cancel()
        contentRevealWorkItem?.cancel()
        panelShrinkWorkItem?.cancel()

        if hovering {
            pillViewModel.isCollapsedContentVisible = false
            setPillFrame(size: PillChromeMetrics.expandedSize, display: true)
            pillPanel.orderFrontRegardless()

            DispatchQueue.main.async { [weak self] in
                guard let self, self.isPointerHoveringPillChrome else { return }

                withAnimation(Metrics.islandAnimation) {
                    self.pillViewModel.isExpanded = true
                }
            }

            let revealWorkItem = DispatchWorkItem { [weak self] in
                guard let self, self.isPointerHoveringPillChrome, self.pillViewModel.isExpanded else { return }

                withAnimation(.easeOut(duration: Metrics.contentFadeDuration)) {
                    self.pillViewModel.isExpandedContentVisible = true
                }
            }
            contentRevealWorkItem = revealWorkItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Metrics.contentRevealDelay,
                execute: revealWorkItem
            )
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            if !self.isPointerHoveringPillChrome {
                withAnimation(.easeOut(duration: Metrics.contentFadeDuration)) {
                    self.pillViewModel.isExpandedContentVisible = false
                }

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
                        self.setPillFrame(size: PillChromeMetrics.collapsedSize, display: true)
                        self.pillViewModel.isCollapsedContentVisible = true
                    }
                    self.panelShrinkWorkItem = shrinkWorkItem
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + Metrics.panelShrinkDelay,
                        execute: shrinkWorkItem
                    )
                }
                self.contentRevealWorkItem = collapseFrameWorkItem
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Metrics.contentFadeDuration,
                    execute: collapseFrameWorkItem
                )
            }
        }

        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: workItem)
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
        guard let pointerScreen = Self.screenContainingMouse() else { return }
        let pointerScreenID = pointerScreen.displayID

        guard currentPillScreenID != pointerScreenID else { return }
        currentPillScreenID = pointerScreenID

        collapseWorkItem?.cancel()
        contentRevealWorkItem?.cancel()
        panelShrinkWorkItem?.cancel()
        pillViewModel.isExpandedContentVisible = false
        pillViewModel.isCollapsedContentVisible = true
        pillViewModel.isExpanded = false

        let targetFrame = Self.topCenterFrame(chromeSize: PillChromeMetrics.collapsedSize, on: pointerScreen)
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
