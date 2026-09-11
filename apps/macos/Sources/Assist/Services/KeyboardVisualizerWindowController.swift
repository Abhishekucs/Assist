import AppKit
import Combine
import SwiftUI

private final class KeyboardVisualizerPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Owns only presentation and pointer tracking; it never installs a keyboard tap.
@MainActor
final class KeyboardVisualizerWindowController {
    private let panel: NSPanel
    private let state: KeyboardVisualizerState
    private var position: KeyboardVisualizerPosition
    private var subscriptions: Set<AnyCancellable> = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var fixedScreenID: CGDirectDisplayID?

    init(controller: KeyboardSoundController, settings: PillSettings) {
        state = controller.visualizer
        position = controller.settings.configuration.visualizerPosition
        panel = KeyboardVisualizerPanel(
            contentRect: CGRect(origin: .zero, size: KeyboardVisualizerPlacement.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.title = "Keyboard Visualizer"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = WindowManager.floatingPanelCollectionBehavior
        panel.contentView = NSHostingView(rootView: KeyboardVisualizerOverlay(state: state, settings: settings, soundSettings: controller.settings))

        state.$isVisible.removeDuplicates().sink { [weak self] visible in
            self?.setVisible(visible)
        }.store(in: &subscriptions)
        controller.settings.$configuration.map(\.visualizerPosition).removeDuplicates().sink { [weak self] position in
            guard let self else { return }
            self.position = position
            self.fixedScreenID = nil
            if self.panel.isVisible { self.updateTracking(); self.reposition() }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                guard let self, self.panel.isVisible else { return }
                self.reposition()
            }.store(in: &subscriptions)
    }

    func stop() {
        stopTracking()
        panel.orderOut(nil)
        subscriptions.removeAll()
    }

    private func setVisible(_ visible: Bool) {
        if visible {
            updateTracking()
            reposition()
            panel.orderFrontRegardless()
        } else {
            stopTracking()
            panel.orderOut(nil)
        }
    }

    private func updateTracking() {
        stopTracking()
        guard position == .followPointer else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        // AppKit event monitors invoke their handlers on the main thread.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.reposition() }
            return event
        }
    }

    private func stopTracking() {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }

    private func reposition() {
        let pointer = NSEvent.mouseLocation
        let pointerScreen = NSScreen.screens.first { $0.frame.contains(pointer) }
        let screen: NSScreen?
        if position == .followPointer {
            screen = pointerScreen
        } else {
            screen = NSScreen.screens.first { $0.displayID == fixedScreenID } ?? pointerScreen
        }
        guard let screen else { return }
        if position != .followPointer { fixedScreenID = screen.displayID }
        let frame = KeyboardVisualizerPlacement.frame(position: position, pointer: pointer, visibleFrame: screen.visibleFrame)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
    }
}
