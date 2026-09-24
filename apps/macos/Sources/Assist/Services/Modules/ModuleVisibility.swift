import AppKit
import Combine

/// Each visible presentation holds one subscription to a shared module service.
@MainActor
protocol VisibleModuleService: AnyObject {
    func start()
    func stop()
}

/// A retained hosting view can outlive its window's visible lifetime. Observe
/// AppKit visibility directly instead of relying on SwiftUI's onDisappear.
@MainActor
final class ModuleVisibility {
    let service: any VisibleModuleService

    private weak var window: NSWindow?
    private var observations: [NSKeyValueObservation] = []
    private var applicationObservation: AnyCancellable?
    private var isViewVisible = true
    private var isActive = false

    init(service: any VisibleModuleService) {
        self.service = service
    }

    func attach(to window: NSWindow?) {
        if let window, self.window === window { return }
        setActive(false)
        observations.removeAll()
        applicationObservation = nil
        self.window = window
        guard let window else { return }

        observations = [
            window.observe(\.isVisible) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.update() }
            },
            window.observe(\.isMiniaturized) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.update() }
            }
        ]
        applicationObservation = NotificationCenter.default
            .publisher(for: NSApplication.didHideNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSApplication.didUnhideNotification))
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            }
        update()
    }

    func setViewVisible(_ visible: Bool) {
        isViewVisible = visible
        update()
    }

    private func update() {
        setActive(isViewVisible && window?.isVisible == true && window?.isMiniaturized == false && !NSApp.isHidden)
    }

    private func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        active ? service.start() : service.stop()
    }
}
