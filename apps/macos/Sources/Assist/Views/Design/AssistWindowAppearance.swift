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
    /// The theme's outer surface for whichever appearance the window resolves to,
    /// so an Assist window never has an unpainted, see-through region.
    static let assistWindowSurface = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(AssistTheme(colorScheme: isDark ? .dark : .light).sidebar)
    }
}
