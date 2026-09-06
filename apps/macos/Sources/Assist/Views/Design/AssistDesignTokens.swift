import SwiftUI

/// Shared visual language for every Assist surface.
///
/// Feature-specific geometry (for example screenshot crop metrics) stays with the
/// feature. Reusable color, typography, spacing, radius, control, icon, opacity,
/// and motion values live here so the island, editor, and control panel do not
/// invent competing styles.
enum AssistDesignTokens {
    enum Palette {
        static let inkComponents = RGBColorComponents(hex: 0x09090B)
        static let elevatedInkComponents = RGBColorComponents(hex: 0x111113)
        static let paperComponents = RGBColorComponents(hex: 0xFAFAFA)

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

    enum HistoryShelf {
        static let cardSize: CGFloat = 142
        static let cardSpacing = Spacing.large
        static let selectionStroke: CGFloat = 1
        static let actionHitArea: CGFloat = 32
        static let actionControl: CGFloat = 24
    }

    enum CaptureLibrary {
        static let minimumCardWidth: CGFloat = 210
        static let maximumCardWidth: CGFloat = 240
        static let cardHeight: CGFloat = 122
        static let gridSpacing = Spacing.xLarge
        static let contentInset = Spacing.xxLarge
        static let cardRadius = Radius.control
        static let selectionStroke: CGFloat = 1
        static let actionInset = Spacing.xSmall
    }

    /// Visual tokens shared by the screenshot editor's card and control primitives.
    /// Capture geometry and crop math remain with the feature models.
    enum ScreenshotEditor {
        static let foreground = Palette.paper
        static let inverseForeground = Palette.ink
        static let surface = Color(hex: 0x0B0B0D)
        static let canvas = Palette.ink

        enum Opacity {
            static let surface: Double = 0.74
            static let cardBorderTop: Double = 0.18
            static let cardBorderBottom: Double = 0.06
            static let canvasBackdrop: Double = 0.52
            static let canvasBackdropScrim: Double = 0.28
            static let imageShadow: Double = 0.35
            static let cropScrim: Double = 0.50
            static let cropGrid: Double = 0.70
            static let divider: Double = 0.07
            static let brushHoverSurface: Double = 0.10
            static let brushIdleSurface: Double = 0.06
            static let brushSelectedStroke: Double = 0.50
            static let swatchBorder: Double = 0.14
            static let sliderTrack: Double = 0.12
            static let sliderFill: Double = 0.92
            static let sliderShadow: Double = 0.35
            static let saveGlow: Double = 0.22
            static let progress: Double = 0.60
        }

        enum Typography {
            static var header: Font {
                .system(size: 10.5, weight: .semibold, design: .rounded)
            }

            static var tool: Font {
                .system(size: 12, weight: .semibold, design: .rounded)
            }

            static var label: Font {
                .system(size: 10.5, weight: .medium, design: .rounded)
            }

            static var chip: Font {
                .system(size: 11, weight: .semibold, design: .rounded)
            }

            static var action: Font {
                .system(size: 12, weight: .semibold, design: .rounded)
            }
        }

        enum Layout {
            static let cardStroke: CGFloat = 1
            static let headerHorizontalInset: CGFloat = 16
            static let imageRadius: CGFloat = 3
            static let imageShadowRadius: CGFloat = 10
            static let imageShadowY: CGFloat = 4
            static let canvasBackdropBlur: CGFloat = 24
            static let cropGridMinimum: CGFloat = 48
            static let cropCornerArm: CGFloat = 14
            static let cropGridStroke: CGFloat = 1
            static let cropCornerStroke: CGFloat = 2.5
            static let controlsHorizontalInset: CGFloat = 16
            static let controlsTopInset: CGFloat = 6
            static let controlsBottomInset: CGFloat = 10
            static let controlsRowSpacing = AssistDesignTokens.Spacing.small
            static let primaryRowHeight: CGFloat = 34
            /// Style needs 28pt swatches, a 6pt gap, and a 24pt slider row.
            static let optionsRowHeight: CGFloat = 58
            static let dividerHeight: CGFloat = 1
            static let transitionOffset: CGFloat = 6
            static let toolChipHorizontalInset: CGFloat = 12
            static let toolChipHeight: CGFloat = 32
            static let chipHorizontalInset: CGFloat = 10
            static let chipHeight: CGFloat = 26
            static let brushButton: CGFloat = 26
            static let brushFineDot: CGFloat = 6
            static let brushMediumDot: CGFloat = 10
            static let brushBoldDot: CGFloat = 14
            static let swatch: CGFloat = 22
            static let selectedSwatch: CGFloat = 28
            static let selectedSwatchStroke: CGFloat = 1.5
            static let emptySwatchMarkWidth: CGFloat = 1.5
            static let emptySwatchMarkHeight: CGFloat = 16
            static let emptySwatchMarkRotation: Double = 45
            static let sliderKnob: CGFloat = 12
            static let sliderTrackHeight: CGFloat = 4
            static let sliderHeight: CGFloat = 24
            static let iconButton: CGFloat = 30
            static let saveHorizontalInset: CGFloat = 12
            static let saveHeight: CGFloat = 32
            static let progressHeight: CGFloat = 2
            static let progressFrameInterval: TimeInterval = 1.0 / 30.0
        }

        enum Scale {
            static let swatchHover: CGFloat = 1.08
            static let swatchSelectionStart: CGFloat = 0.8
            static let sliderHover: CGFloat = 1.08
            static let sliderDrag: CGFloat = 1.18
            static let saveHover: CGFloat = 1.03
            static let wallpaperRevealStart: CGFloat = 0.6
        }

        enum Motion {
            static var progressReveal: Animation { .easeOut(duration: 0.2) }
            static var canvasChange: Animation { .easeOut(duration: 0.18) }
            static var optionsChange: Animation { .spring(response: 0.3, dampingFraction: 0.86) }
            static var toolSelection: Animation { .spring(response: 0.3, dampingFraction: 0.82) }
            static var wallpaperReveal: Animation { .spring(response: 0.3, dampingFraction: 0.8) }
            static var labelChange: Animation { .easeOut(duration: 0.16) }
            static var hover: Animation { .easeOut(duration: 0.14) }
            static var selection: Animation { .spring(response: 0.26, dampingFraction: 0.8) }
            static var sliderDrag: Animation { .spring(response: 0.22, dampingFraction: 0.7) }
            static var saveHover: Animation { .spring(response: 0.24, dampingFraction: 0.72) }
            static var saving: Animation { .easeOut(duration: 0.16) }
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
    var cardColorComponents: RGBColorComponents {
        isDark ? AssistDesignTokens.Palette.elevatedInkComponents : .white
    }
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
