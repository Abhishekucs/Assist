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

extension NSWindow {
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

    private static func assistThemeColor(_ role: KeyPath<AssistTheme, Color> & Sendable) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(AssistTheme(colorScheme: isDark ? .dark : .light)[keyPath: role])
        }
    }
}
