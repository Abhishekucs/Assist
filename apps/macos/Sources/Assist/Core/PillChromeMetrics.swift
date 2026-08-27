import CoreGraphics

// Shared geometry for the capture shelf and its native window hit-testing.
enum PillChromeMetrics {
    static let collapsedTopCornerRadius = PillSettings.Defaults.collapsedTopCornerRadius
    static let collapsedBottomCornerRadius = PillSettings.Defaults.collapsedBottomCornerRadius
    static let expandedTopCornerRadius = PillSettings.Defaults.expandedTopCornerRadius
    static let expandedBottomCornerRadius = PillSettings.Defaults.expandedBottomCornerRadius
    static let topInset = PillSettings.Defaults.topInset
    static let copyFeedbackWidthBoost: CGFloat = 120
    static let compactExpandedHeight: CGFloat = 210

    static func collapsedSize(settings: PillSettings, showingCopyFeedback: Bool = false) -> CGSize {
        var size = settings.collapsedSize
        if showingCopyFeedback {
            size.width = min(size.width + copyFeedbackWidthBoost, expandedSize(settings: settings).width)
        }
        return size
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
