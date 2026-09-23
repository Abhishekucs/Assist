import SwiftUI

/// Short name for `AssistDesignTokens` at call sites.
typealias Tokens = AssistDesignTokens

/// Shared visual language for every Assist surface.
///
/// Feature-specific geometry (for example screenshot crop metrics) stays with the
/// feature. Reusable color, typography, spacing, radius, control, icon, opacity,
/// and motion values live here so the island, editor, and control panel do not
/// invent competing styles.
enum AssistDesignTokens {
    enum Palette {
        static let inkComponents = RGBColorComponents(hex: 0x09090B)

        static let ink = Color(hex: 0x09090B)
        static let elevatedInk = Color(hex: 0x111113)
        static let paper = Color(hex: 0xFAFAFA)
        static let softPaper = Color(hex: 0xF4F4F5)
        static let zinc = Color(hex: 0x71717A)

        // Sampled visual roles from the supplied Willow references. Keep the
        // notch's black silhouette separate from the window surface palette.
        static let window = Color(hex: 0xF4F4F6)
        static let text = Color(hex: 0x3D3D42)
        // Darker than the reference sample so captions stay at or above 4.5:1
        // on every light surface they sit on, including selected rows and lavender.
        static let secondaryText = Color(hex: 0x5F5F66)
        static let separator = Color(hex: 0xE0E0E5)
        /// A faint tint so white groups and cards read on the white content surface.
        static let cardComponents = RGBColorComponents(hex: 0xF8F8FA)
        static let purple = Color(hex: 0x5142B8)
        static let lavenderComponents = RGBColorComponents(hex: 0xEEEBFA)
        static let darkPurple = Color(hex: 0xB6A9FF)
        /// Label on a `darkPurple` fill; dark surfaces use that lighter fill so
        /// primary actions keep 3:1 against them.
        static let onDarkPurple = Color(hex: 0x17122E)
        // Outlines for inputs, buttons, and option tiles keep at least 3:1
        // against every surface they sit on (WCAG non-text contrast).
        static let lightControlBorder = Color(hex: 0x84848C)
        static let darkControlBorder = Color(hex: 0x807F88)

        static let warning = Color(hex: 0xFF751F)
        static let danger = Color(hex: 0xFF453A)
        static let lightDangerText = Color(hex: 0xD70015)
        static let darkDangerText = Color(hex: 0xFF6961)
    }

    enum Opacity {
        static let primary: Double = 0.94
        static let strong: Double = 0.86
        static let secondary: Double = 0.70
        static let muted: Double = 0.52
        static let subtle: Double = 0.36
        /// Disabled glyphs on the island and editor's dark surfaces.
        static let disabled: Double = 0.34
        static let quietSurface: Double = 0.08
        static let hoverSurface: Double = 0.14
        static let destructiveHoverSurface: Double = 0.12
        /// Foreground tints for hovered and selected rows and icon buttons, so
        /// both read on whichever surface they sit on.
        static let hoverFill: Double = 0.06
        static let selectedFill: Double = 0.11
        /// Pressed and disabled buttons, fields, and icon buttons in app windows.
        static let pressedControl: Double = 0.76
        static let disabledControl: Double = 0.42
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
        static let keycap: CGFloat = 6
        static let control: CGFloat = 7
        static let iconButton: CGFloat = 8
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let window: CGFloat = 18
    }

    /// Selections and primary actions on the island and editor's dark surfaces.
    enum DarkSurface {
        static let selectionFill = Palette.purple.opacity(0.28)
        static let selectionForeground = Palette.darkPurple
        static let primaryFill = Palette.darkPurple
        static let primaryForeground = Palette.onDarkPurple
    }

    /// The island's black-and-white module surfaces: white ink on the notch's
    /// black, with selection shown as an inverted white fill and black ink.
    enum Mono {
        static let ink = Palette.paper
        static let selectedFill = Palette.paper
        static let selectedForeground = Palette.ink
        /// Resting tiles, fields, and drop zones.
        static let surface = Palette.paper.opacity(Opacity.quietSurface)
        static let hoverSurface = Palette.paper.opacity(Opacity.hoverSurface)
        /// The empty part of a meter and the outline of a drop zone.
        static let track = Palette.paper.opacity(Opacity.hoverSurface)
        static let meter = Palette.paper.opacity(Opacity.primary)
        static let dropOutline = Palette.paper.opacity(Opacity.subtle)
        static let dropTargetOutline = Palette.paper.opacity(Opacity.primary)
    }

    /// Geometry shared by every module on the island.
    enum ModuleIsland {
        /// Module content below the tab row: a toolbar, a gap, and a
        /// capture-card-tall body. `PillChromeMetrics.moduleExpandedHeight`
        /// adds the tab row and insets around it.
        static let toolbarHeight = Control.compactHeight
        static let toolbarSpacing = Spacing.small
        static let bodyHeight = HistoryShelf.cardSize
        static let contentHeight = toolbarHeight + toolbarSpacing + bodyHeight
        static let tabRowHeight = Control.regularHeight
        static let tabIcon = Icon.regular
        static let tileRadius = Radius.medium
        static let shelfTileWidth: CGFloat = 92
        static let meterHeight: CGFloat = 4
        static let dropOutlineWidth: CGFloat = 1
        static let dropOutlineDash: [CGFloat] = [4, 4]
    }

    /// Library window layout.
    enum AppLayout {
        static let sidebarWidth: CGFloat = 196
        /// Inset of sidebar content, which also insets navigation row contents.
        static let sidebarInset: CGFloat = 12
        /// Space between the title bar and the sidebar wordmark.
        static let sidebarTopInset: CGFloat = 10
        static let navigationRowHeight: CGFloat = 36
        /// Gap between the window edge and the inset content pane.
        static let paneInset: CGFloat = 8
    }

    enum Settings {
        /// Shared leading and trailing inset for every row inside a settings group.
        static let rowInset: CGFloat = 16
        static let rowHeight: CGFloat = 46
        static let detailedRowHeight: CGFloat = 60
        static let dialogSize = CGSize(width: 820, height: 560)
        static let dialogInset: CGFloat = 22
        static let columnSpacing: CGFloat = 28
        /// Aligns the sidebar title with the page title beside it.
        static let headerTopInset: CGFloat = 7
        static let pickerWidth: CGFloat = 166
        /// The close button's inset from the dialog's top-right corner.
        static let closeButtonInset = Spacing.medium
        /// Keeps a page header clear of the close button, which overlays the
        /// dialog's top-right corner.
        static let closeButtonClearance = Control.largeIconButton + closeButtonInset + Spacing.small - dialogInset
    }

    enum Control {
        static let compactHeight: CGFloat = 24
        static let regularHeight: CGFloat = 30
        static let mediumHeight: CGFloat = 32
        static let largeHeight: CGFloat = 36
        static let heroHeight: CGFloat = 42
        static let iconButton: CGFloat = 30
        static let largeIconButton: CGFloat = 34
        static let tooltipHeight: CGFloat = 22
        static let borderWidth: CGFloat = 1
        static let focusRingWidth: CGFloat = 2
    }

    enum Icon {
        static let small: CGFloat = 12
        static let regular: CGFloat = 14
        static let medium: CGFloat = 15
        static let navigation: CGFloat = 17
        static let feedback: CGFloat = 18
        static let tile: CGFloat = 22
        static let placeholder: CGFloat = 30
        static let emptyState: CGFloat = 32
    }

    enum Typography {
        /// Window headings.
        static var largeTitle: Font {
            .system(size: 24, weight: .medium)
        }

        /// The Assist wordmark.
        static var title: Font {
            .system(size: 20, weight: .medium)
        }

        /// Prominent regular-weight guidance, such as the library welcome line.
        static var display: Font {
            .system(size: 20)
        }

        /// Settings page and empty-state headings.
        static var pageTitle: Font {
            .system(size: 17, weight: .medium)
        }

        /// Headings above a list, such as History.
        static var sectionTitle: Font {
            .system(size: 15, weight: .medium)
        }

        /// Navigation, row, and tile labels.
        static func label(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 13, weight: weight)
        }

        /// Labels above a settings group or navigation list.
        static var section: Font {
            .system(size: 12)
        }

        static var keycap: Font {
            .system(size: 12, weight: .medium)
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

        static var headline: Font {
            .headline
        }

        static func footnote(_ weight: Font.Weight = .regular) -> Font {
            .footnote.weight(weight)
        }

        /// The smallest island labels, such as a capture's context.md preview.
        static func micro(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 8.5, weight: weight)
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
        /// The selected card's rings: a light outer ring and a dark inner one,
        /// so at least one contrasts with any thumbnail, tint, or color clip.
        static let selectionRingWidth: CGFloat = 1.5
        static let selectionRingOuter = Palette.paper.opacity(Opacity.primary)
        static let selectionRingInnerWidth: CGFloat = 1
        static let selectionRingInner = Palette.ink.opacity(Opacity.strong)
        static let actionHitArea: CGFloat = 32
        static let actionControl: CGFloat = 24
    }

    /// Muted, grainy tints for history cards on the island's black surface,
    /// sampled from the design reference. Text on a tint uses its dark `ink`.
    enum IslandCard {
        struct Tint: Equatable, Sendable {
            let fillHex: UInt32
            let inkHex: UInt32

            var fill: Color { Color(hex: fillHex) }
            var ink: Color { Color(hex: inkHex) }
            /// Smaller labels on the tint; still at least 4.5:1.
            var secondaryInk: Color { ink.opacity(IslandCard.secondaryInkOpacity) }
        }

        // Fills are the sampled reference colors; the grain averages to zero,
        // so cards keep them on screen. Inks are near-black with a trace of
        // the tint's hue, for crisp text.
        static let sage = Tint(fillHex: 0x98B3A3, inkHex: 0x050F08)
        static let lavender = Tint(fillHex: 0xA7A1BD, inkHex: 0x0B0914)
        static let mustard = Tint(fillHex: 0xB2AC75, inkHex: 0x0F0B02)
        static let dustyBlue = Tint(fillHex: 0x96AEBF, inkHex: 0x040C12)

        /// Text clips rotate through these; voice-context captures keep the
        /// blue that marks them as a folder.
        static let textTints = [sage, lavender, mustard]
        static let contextTint = dustyBlue

        static let secondaryInkOpacity: Double = 0.9
        /// The largest brightness change the grain makes to a pixel, up or down.
        static let grainAmplitude: Double = 0.04

        /// A clip's tint, derived from its id so it stays the same across launches.
        static func textTint(for id: UUID) -> Tint {
            textTints[Int(id.uuid.0) % textTints.count]
        }
    }

    enum CaptureLibrary {
        static let minimumCardWidth: CGFloat = 190
        static let maximumCardWidth: CGFloat = 280
        static let cardHeight: CGFloat = 136
        static let gridSpacing = Spacing.xLarge
        static let contentInset = Spacing.xxxLarge
        /// Space between the title bar and the library header.
        static let headerTopInset = Spacing.small
        static let cardRadius = Radius.medium
        static let borderStroke = Control.borderWidth
        /// Thicker than the border, so selection is not signalled by color alone.
        static let selectionStroke: CGFloat = 2
        static let actionInset = Spacing.xSmall
    }

    /// Visual tokens shared by the screenshot editor's card and control primitives.
    /// Capture geometry and crop math remain with the feature models.
    enum ScreenshotEditor {
        static let foreground = Palette.paper
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
                .system(size: 10.5, weight: .semibold, design: .default)
            }

            static var tool: Font {
                .system(size: 12, weight: .semibold, design: .default)
            }

            static var label: Font {
                .system(size: 10.5, weight: .medium, design: .default)
            }

            static var chip: Font {
                .system(size: 11, weight: .semibold, design: .default)
            }

            static var action: Font {
                .system(size: 12, weight: .semibold, design: .default)
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
            static var presentation: Animation { .smooth(duration: 0.42) }
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
    var background: Color { isDark ? Color(hex: 0x202024) : .white }
    var sidebar: Color { isDark ? Color(hex: 0x19191D) : AssistDesignTokens.Palette.window }
    var card: Color { Color(rgb: cardComponents) }
    /// Resting keys in the Assist keyboard visualizer.
    var keyFill: Color { isDark ? Color(hex: 0x333239) : Color(hex: 0xEAE9ED) }
    var foreground: Color { isDark ? Color(hex: 0xEEEEF2) : AssistDesignTokens.Palette.text }
    var muted: Color { isDark ? Color(hex: 0xABAAB3) : AssistDesignTokens.Palette.secondaryText }
    var dangerText: Color {
        isDark ? AssistDesignTokens.Palette.darkDangerText : AssistDesignTokens.Palette.lightDangerText
    }
    var border: Color { isDark ? Color(hex: 0x38373E) : AssistDesignTokens.Palette.separator }
    var accent: Color { isDark ? AssistDesignTokens.Palette.darkPurple : AssistDesignTokens.Palette.purple }
    var accentSurface: Color { Color(rgb: accentSurfaceComponents) }
    var primaryButton: Color {
        isDark ? AssistDesignTokens.DarkSurface.primaryFill : AssistDesignTokens.Palette.purple
    }
    var primaryButtonForeground: Color {
        isDark ? AssistDesignTokens.DarkSurface.primaryForeground : .white
    }
    /// The scheme for controls drawn on a primary fill (such as a progress
    /// spinner): a dark purple in light appearance, a light one in dark.
    var primaryButtonContentScheme: ColorScheme { isDark ? .light : .dark }
    var control: Color { Color(rgb: controlComponents) }
    var hoverFill: Color { foreground.opacity(AssistDesignTokens.Opacity.hoverFill) }
    var selectedFill: Color { foreground.opacity(AssistDesignTokens.Opacity.selectedFill) }
    var controlBorder: Color {
        isDark ? AssistDesignTokens.Palette.darkControlBorder : AssistDesignTokens.Palette.lightControlBorder
    }

    // Opaque surfaces as components, so text over translucent content (such as
    // a clipboard color) can be judged against the surface actually behind it.
    var cardComponents: RGBColorComponents {
        isDark ? RGBColorComponents(hex: 0x25252B) : AssistDesignTokens.Palette.cardComponents
    }
    var controlComponents: RGBColorComponents {
        isDark ? RGBColorComponents(hex: 0x2D2D33) : RGBColorComponents(hex: 0xF5F5F6)
    }
    var accentSurfaceComponents: RGBColorComponents {
        isDark ? RGBColorComponents(hex: 0x353047) : AssistDesignTokens.Palette.lavenderComponents
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

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0
        )
    }

    init(rgb components: RGBColorComponents) {
        self.init(red: components.red, green: components.green, blue: components.blue)
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
