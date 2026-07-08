import AppKit
import SwiftUI

enum SystemAppearanceResolver {
    static let changeNotification = Notification.Name("AppleInterfaceThemeChangedNotification")

    @MainActor
    static func currentColorScheme() -> ColorScheme {
        if let globalStyle = UserDefaults.standard
            .persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String {
            return globalStyle.localizedCaseInsensitiveContains("dark") ? .dark : .light
        }

        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }
}
