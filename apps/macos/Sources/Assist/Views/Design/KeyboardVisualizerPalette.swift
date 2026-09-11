import SwiftUI

/// Native interpretations of the six keycap palettes in the user's Keeby
/// reference. Source colors and design attribution are recorded in docs/keyboard-catalog.md.
struct KeyboardVisualizerPalette {
    let style: KeyboardVisualizerStyle

    func fill(for code: UInt16) -> UInt32 {
        let colors: (alpha: UInt32, modifier: UInt32, accent: UInt32)
        switch style {
        case .assist: colors = (0x27272A, 0x27272A, 0xFAFAFA)
        case .classic: colors = (0xF5F5F5, 0x737373, 0xF57644)
        case .mint: colors = (0xEEEEEE, 0x447B82, 0x86C8AC)
        case .royal: colors = (0x324974, 0x3A3B35, 0xE4D440)
        case .dolch: colors = (0x4F5E78, 0x3E3B4C, 0xD73E42)
        case .sand: colors = (0xEFEFEF, 0x893D36, 0xC94E41)
        case .scarlet: colors = (0xE4D7D7, 0xD5868A, 0xE1E1E1)
        }
        if accentKeys.contains(code) { return colors.accent }
        if Self.modifierKeys.contains(code) || (style == .classic && [36, 42].contains(code))
            || (style == .dolch && [50, 42].contains(code)) { return colors.modifier }
        return colors.alpha
    }

    func text(for code: UInt16) -> UInt32 {
        // Preserve the reference's colors while keeping tiny legends legible.
        let color = fill(for: code)
        let components = [16, 8, 0].map { shift -> Double in
            let c = Double((color >> shift) & 0xff) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2]
        return luminance > 0.179 ? 0x000000 : 0xFFFFFF
    }

    private var accentKeys: Set<UInt16> {
        switch style {
        case .assist, .classic: [53]
        case .mint, .royal: [53, 36, 123, 124, 125, 126]
        case .dolch: [53, 36, 49]
        case .sand, .scarlet: [53, 36]
        }
    }

    private static let modifierKeys: Set<UInt16> = [
        96, 97, 98, 100, 101, 117, 51, 48, 57, 56, 60, 59, 62, 58, 61, 55, 54, 63
    ]
}
