import SwiftUI

/// Shared visual language for every Assist surface.
///
/// Feature-specific geometry (for example screenshot crop metrics) stays with the
/// feature. Reusable color, typography, spacing, radius, control, icon, opacity,
/// and motion values live here so the island, editor, and control panel do not
/// invent competing styles.
enum AssistDesignTokens {
    enum Palette {
        static let ink = Color(hex: 0x09090B)
        static let elevatedInk = Color(hex: 0x111113)
        static let paper = Color(hex: 0xFAFAFA)
        static let softPaper = Color(hex: 0xF4F4F5)
        static let zinc = Color(hex: 0x71717A)
        static let softZinc = Color(hex: 0xA1A1AA)

        static let warning = Color(hex: 0xFF751F)
        static let danger = Color(hex: 0xFF453A)
        static let folder = Color(hex: 0x118AF3)
    }

    enum Opacity {
        static let primary: Double = 0.94
        static let strong: Double = 0.86
        static let secondary: Double = 0.70
        static let muted: Double = 0.52
        static let subtle: Double = 0.36
        static let disabled: Double = 0.34
        static let selectedStroke: Double = 0.72
        static let quietSurface: Double = 0.08
        static let hoverSurface: Double = 0.14
        static let destructiveHoverSurface: Double = 0.12
    }

    enum Spacing {
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 8
        static let medium: CGFloat = 10
        static let large: CGFloat = 12
        static let xLarge: CGFloat = 14
        static let xxLarge: CGFloat = 18
        static let xxxLarge: CGFloat = 24
        static let shelfInset: CGFloat = 30
    }

    enum Radius {
        static let small: CGFloat = 5
        static let control: CGFloat = 7
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
    }

    enum Control {
        static let compactHeight: CGFloat = 24
        static let regularHeight: CGFloat = 30
        static let iconButton: CGFloat = 30
        static let tooltipHeight: CGFloat = 22
    }

    enum Icon {
        static let small: CGFloat = 12
        static let regular: CGFloat = 14
        static let feedback: CGFloat = 18
    }

    enum Typography {
        static var title: Font {
            .system(.title3, design: .default).weight(.semibold)
        }

        static var section: Font {
            .caption.weight(.medium)
        }

        static func body(_ weight: Font.Weight = .regular) -> Font {
            .body.weight(weight)
        }

        static func small(_ weight: Font.Weight = .regular) -> Font {
            .subheadline.weight(weight)
        }

        static func caption(_ weight: Font.Weight = .regular) -> Font {
            .caption.weight(weight)
        }

        static var roundedHeadline: Font {
            .system(.headline, design: .rounded)
        }

        static func roundedFootnote(_ weight: Font.Weight = .regular) -> Font {
            .system(.footnote, design: .rounded).weight(weight)
        }

        static var mono: Font {
            .system(.caption, design: .monospaced).weight(.medium)
        }
    }

    enum Motion {
        static var island: Animation {
            .interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
        }

        static var feedback: Animation {
            .spring(response: 0.34, dampingFraction: 0.7)
        }

        static var quick: Animation {
            .easeOut(duration: 0.12)
        }
    }
}

struct AssistTheme {
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }
    var background: Color { isDark ? AssistDesignTokens.Palette.ink : AssistDesignTokens.Palette.paper }
    var sidebar: Color { isDark ? Color(hex: 0x0C0C0F) : AssistDesignTokens.Palette.softPaper }
    var card: Color { isDark ? AssistDesignTokens.Palette.elevatedInk : .white }
    var selected: Color { isDark ? Color(hex: 0x27272A) : Color(hex: 0xEDEDEF) }
    var foreground: Color { isDark ? AssistDesignTokens.Palette.paper : AssistDesignTokens.Palette.ink }
    var muted: Color { isDark ? AssistDesignTokens.Palette.softZinc : AssistDesignTokens.Palette.zinc }
    var subtle: Color { isDark ? AssistDesignTokens.Palette.zinc : AssistDesignTokens.Palette.softZinc }
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

/// Compatibility gateway for existing views. New design values should be added
/// to `AssistDesignTokens.Typography`, keeping this API intentionally thin.
enum AssistFont {
    static func title() -> Font { AssistDesignTokens.Typography.title }
    static func section() -> Font { AssistDesignTokens.Typography.section }
    static func body(_ weight: Font.Weight = .regular) -> Font { AssistDesignTokens.Typography.body(weight) }
    static func small(_ weight: Font.Weight = .regular) -> Font { AssistDesignTokens.Typography.small(weight) }
    static func caption(_ weight: Font.Weight = .regular) -> Font { AssistDesignTokens.Typography.caption(weight) }
    static func roundedHeadline() -> Font { AssistDesignTokens.Typography.roundedHeadline }
    static func roundedFootnote(_ weight: Font.Weight = .regular) -> Font {
        AssistDesignTokens.Typography.roundedFootnote(weight)
    }
    static func mono() -> Font { AssistDesignTokens.Typography.mono }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0
        )
    }

    init(clipboardColor: ClipboardColorCode) {
        self.init(
            red: clipboardColor.red,
            green: clipboardColor.green,
            blue: clipboardColor.blue,
            opacity: clipboardColor.alpha
        )
    }
}
