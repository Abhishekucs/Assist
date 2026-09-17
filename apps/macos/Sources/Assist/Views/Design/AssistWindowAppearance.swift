import AppKit
import Combine
import SwiftUI

extension AppAppearance {
    /// `nil` lets a window inherit the live macOS appearance.
    var windowAppearance: NSAppearance? {
        switch self {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .system: nil
        }
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

private struct TitleBarInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Height of the transparent title bar that a window's content runs under.
    /// Assist windows turn off SwiftUI's own safe area, so each window is exactly
    /// its view's size; a window's root view restores it with
    /// `titleBarSafeArea()`.
    var titleBarInset: CGFloat {
        get { self[TitleBarInsetKey.self] }
        set { self[TitleBarInsetKey.self] = newValue }
    }
}

private struct TitleBarSafeArea: ViewModifier {
    @Environment(\.titleBarInset) private var inset

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: inset)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Makes the window's title bar a top safe area for this view's content,
    /// as SwiftUI's own safe area would. Apply it in a window's root view,
    /// before any frame that sets the window's size, so the title bar is part
    /// of that size. Backgrounds still extend under the title bar.
    func titleBarSafeArea() -> some View {
        modifier(TitleBarSafeArea())
    }
}

/// Tracks a window's title bar height as it changes, for example when the
/// window enters or leaves full screen or gains a toolbar.
///
/// The window owns this object through its hosting view, so neither
/// observation holds the window strongly.
@MainActor
final class WindowTitleBarMetrics: ObservableObject {
    @Published private(set) var inset: CGFloat
    private var layoutObservation: NSKeyValueObservation?
    private var subscriptions: Set<AnyCancellable> = []

    init(window: NSWindow) {
        inset = window.titleBarInset
        layoutObservation = window.observe(\.contentLayoutRect) { [weak self] window, _ in
            MainActor.assumeIsolated {
                self?.update(from: window)
            }
        }
        // Filtering by identity, rather than passing the window as the
        // notification object, keeps these subscriptions from retaining it.
        NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification))
            .sink { [weak self, weak window] notification in
                guard let window, notification.object as? NSWindow === window else { return }
                self?.update(from: window)
            }
            .store(in: &subscriptions)
    }

    private func update(from window: NSWindow) {
        let inset = window.titleBarInset
        if inset != self.inset {
            self.inset = inset
        }
    }
}

/// Supplies a window's live `titleBarInset` to its SwiftUI content.
struct TitleBarInsetReader<Content: View>: View {
    @ObservedObject var metrics: WindowTitleBarMetrics
    let content: Content

    var body: some View {
        content.environment(\.titleBarInset, metrics.inset)
    }
}

extension NSWindow {
    /// The part of the window's height covered by its title bar.
    var titleBarInset: CGFloat {
        frame.height - contentLayoutRect.height
    }

    /// Wraps a root view so it reads this window's live `titleBarInset`.
    func withTitleBarInset<Content: View>(_ content: Content) -> TitleBarInsetReader<Content> {
        TitleBarInsetReader(metrics: WindowTitleBarMetrics(window: self), content: content)
    }

    /// Chrome shared by Assist's titled windows: content runs under a hidden,
    /// transparent title bar on an opaque themed background, and the window
    /// follows the persisted Appearance preference. Keep the returned
    /// subscription for as long as the window lives.
    func applyAssistChrome(background: NSColor, appearanceFrom settings: PillSettings) -> AnyCancellable {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = background
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        return followAppearance(of: settings)
    }

    /// Applies the persisted Appearance preference to this window. SwiftUI content
    /// reads the result through `\.colorScheme`, so System tracks macOS directly.
    func followAppearance(of settings: PillSettings) -> AnyCancellable {
        settings.$appAppearance.sink { [weak self] appearance in
            self?.appearance = appearance.windowAppearance
        }
    }
}

extension NSColor {
    // A window's background matches the SwiftUI surface it hosts, resolved for
    // whichever appearance the window uses, so no region is ever see-through.

    /// The library window's outer frame behind its sidebar.
    static let assistWindowSurface = assistThemeColor(\.sidebar)
    /// The activation window, which is a single content surface.
    static let assistContentSurface = assistThemeColor(\.background)

    private static func assistThemeColor(_ role: KeyPath<AssistTheme, Color>) -> NSColor {
        let light = NSColor(AssistTheme(colorScheme: .light)[keyPath: role])
        let dark = NSColor(AssistTheme(colorScheme: .dark)[keyPath: role])
        return NSColor(name: nil) { appearance in
            appearance.isDark ? dark : light
        }
    }
}
