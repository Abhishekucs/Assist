import SwiftUI

struct AssistTheme {
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }
    var background: Color { isDark ? Color(hex: 0x09090B) : Color(hex: 0xFAFAFA) }
    var sidebar: Color { isDark ? Color(hex: 0x0C0C0F) : Color(hex: 0xF4F4F5) }
    var card: Color { isDark ? Color(hex: 0x111113) : Color.white }
    var selected: Color { isDark ? Color(hex: 0x27272A) : Color(hex: 0xEDEDEF) }
    var foreground: Color { isDark ? Color(hex: 0xFAFAFA) : Color(hex: 0x09090B) }
    var muted: Color { isDark ? Color(hex: 0xA1A1AA) : Color(hex: 0x71717A) }
    var subtle: Color { isDark ? Color(hex: 0x71717A) : Color(hex: 0xA1A1AA) }
    var border: Color { isDark ? Color(hex: 0x27272A) : Color(hex: 0xE4E4E7) }
    var accent: Color { foreground }
}

private struct AssistThemeKey: EnvironmentKey {
    static let defaultValue = AssistTheme(colorScheme: .dark)
}

extension EnvironmentValues {
    var assistTheme: AssistTheme {
        get { self[AssistThemeKey.self] }
        set { self[AssistThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0
        )
    }
}
