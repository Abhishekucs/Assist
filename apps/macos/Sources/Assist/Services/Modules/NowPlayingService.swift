import AppKit
import Combine

/// Follows Music and Spotify through their public playback notifications and
/// controls playback with the system media keys, which reach whichever app
/// owns Now Playing. Sending keys needs the Accessibility access Assist
/// already uses for its capture shortcuts.
@MainActor
final class NowPlayingService: NSObject, ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var needsAccessibility = false

    private var isObserving = false
    private var terminationCancellable: AnyCancellable?

    func start() {
        guard !isObserving else { return }
        isObserving = true

        let center = DistributedNotificationCenter.default()
        for source in NowPlayingInfo.Source.allCases {
            // An accessory app is rarely active, so deliver immediately rather
            // than holding notifications until Assist comes to the front.
            center.addObserver(
                self,
                selector: #selector(playerInfoChanged(_:)),
                name: source.notificationName,
                object: nil,
                suspensionBehavior: .deliverImmediately
            )
        }

        terminationCancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let bundleIdentifier = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                    .bundleIdentifier
                MainActor.assumeIsolated {
                    self?.playerQuit(bundleIdentifier: bundleIdentifier)
                }
            }
    }

    func stop() {
        guard isObserving else { return }
        isObserving = false
        DistributedNotificationCenter.default().removeObserver(self)
        terminationCancellable = nil
        info = nil
    }

    func send(_ key: MediaKey) {
        guard AXIsProcessTrusted() else {
            needsAccessibility = true
            return
        }
        needsAccessibility = false

        for isKeyDown in [true, false] {
            let state = isKeyDown ? 0xA : 0xB
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                subtype: 8,
                data1: (key.rawValue << 16) | (state << 8),
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func openPlayer() {
        let bundleIdentifier = info?.source.bundleIdentifier ?? NowPlayingInfo.Source.music.bundleIdentifier
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    @objc private func playerInfoChanged(_ notification: Notification) {
        guard let source = NowPlayingInfo.Source.allCases.first(where: { $0.notificationName == notification.name }) else {
            return
        }

        let next = notification.userInfo.flatMap { NowPlayingInfo(source: source, userInfo: $0) }
        if let next {
            info = next
        } else if info?.source == source {
            // The player that was showing stopped.
            info = nil
        }
    }

    private func playerQuit(bundleIdentifier: String?) {
        guard let bundleIdentifier, info?.source.bundleIdentifier == bundleIdentifier else { return }
        info = nil
    }
}
