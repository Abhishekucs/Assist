import Foundation

/// WCAG 2 relative luminance and contrast ratio for sRGB colors, shared by the
/// app and its tests.
enum ColorContrast {
    static func relativeLuminance(of color: RGBColorComponents) -> Double {
        (0.2126 * linearized(color.red))
            + (0.7152 * linearized(color.green))
            + (0.0722 * linearized(color.blue))
    }

    static func ratio(_ first: RGBColorComponents, _ second: RGBColorComponents) -> Double {
        let firstLuminance = relativeLuminance(of: first)
        let secondLuminance = relativeLuminance(of: second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private static func linearized(_ component: Double) -> Double {
        let component = min(max(component, 0), 1)
        if component <= 0.04045 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }
}
