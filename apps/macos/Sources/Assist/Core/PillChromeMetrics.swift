import CoreGraphics

enum PillChromeMetrics {
    static let collapsedTopCornerRadius = PillSettings.Defaults.collapsedTopCornerRadius
    static let collapsedBottomCornerRadius = PillSettings.Defaults.collapsedBottomCornerRadius
    static let expandedTopCornerRadius = PillSettings.Defaults.expandedTopCornerRadius
    static let expandedBottomCornerRadius = PillSettings.Defaults.expandedBottomCornerRadius
    static let topInset = PillSettings.Defaults.topInset
    static let copyFeedbackWidthBoost: CGFloat = 120

    static func collapsedSize(settings: PillSettings) -> CGSize {
        settings.collapsedSize
    }

    static func collapsedSize(settings: PillSettings, showingCopyFeedback: Bool) -> CGSize {
        var size = settings.collapsedSize

        if showingCopyFeedback {
            size.width = min(
                size.width + copyFeedbackWidthBoost,
                expandedSize(settings: settings).width
            )
        }

        return size
    }

    static func expandedSize(settings: PillSettings) -> CGSize {
        settings.expandedSize
    }

    static func topCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedTopCornerRadius : collapsedTopCornerRadius
    }

    static func bottomCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedBottomCornerRadius : collapsedBottomCornerRadius
    }

}
