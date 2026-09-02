import CoreGraphics

// Shared geometry for the capture shelf and its native window hit-testing.
enum PillChromeMetrics {
    static let collapsedTopCornerRadius = PillSettings.Defaults.collapsedTopCornerRadius
    static let collapsedBottomCornerRadius = PillSettings.Defaults.collapsedBottomCornerRadius
    static let expandedTopCornerRadius = PillSettings.Defaults.expandedTopCornerRadius
    static let expandedBottomCornerRadius = PillSettings.Defaults.expandedBottomCornerRadius
    static let topInset = PillSettings.Defaults.topInset
    static let compactExpandedHeight: CGFloat = 210

    // The collapsed island keeps one width; feedback is a glyph, so it never grows the chrome.
    static func collapsedSize(settings: PillSettings) -> CGSize {
        settings.collapsedSize
    }

    static func expandedSize(settings: PillSettings) -> CGSize {
        var size = settings.expandedSize
        // Preserve the existing capture-only gallery height, including old size preferences.
        size.height = min(size.height, compactExpandedHeight)
        return size
    }

    static func topCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedTopCornerRadius : collapsedTopCornerRadius
    }

    static func bottomCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedBottomCornerRadius : collapsedBottomCornerRadius
    }
}
