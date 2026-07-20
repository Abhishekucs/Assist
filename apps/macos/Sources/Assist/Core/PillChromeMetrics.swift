import CoreGraphics

enum PillChromeMetrics {
    static let collapsedTopCornerRadius = PillSettings.Defaults.collapsedTopCornerRadius
    static let collapsedBottomCornerRadius = PillSettings.Defaults.collapsedBottomCornerRadius
    static let expandedTopCornerRadius = PillSettings.Defaults.expandedTopCornerRadius
    static let expandedBottomCornerRadius = PillSettings.Defaults.expandedBottomCornerRadius
    static let topInset = PillSettings.Defaults.topInset
    static let copyFeedbackWidthBoost: CGFloat = 120
    static let agentActivityWidthBoost: CGFloat = 82
    static let compactExpandedHeight: CGFloat = 210
    static let rateLimitExpandedHeight: CGFloat = 234
    static let agentApprovalExpandedMinHeight: CGFloat = 250
    static let agentTasksExpandedBaseHeight: CGFloat = 280
    static let agentTaskRowHeightBoost: CGFloat = 40

    static func collapsedSize(settings: PillSettings) -> CGSize {
        settings.collapsedSize
    }

    static func collapsedSize(
        settings: PillSettings,
        showingCopyFeedback: Bool,
        showingAgentActivity: Bool = false
    ) -> CGSize {
        var size = settings.collapsedSize

        if showingCopyFeedback || showingAgentActivity {
            let widthBoost = showingCopyFeedback
                ? copyFeedbackWidthBoost
                : agentActivityWidthBoost
            size.width = min(
                size.width + widthBoost,
                expandedSize(settings: settings).width
            )
        }

        return size
    }

    static func expandedSize(settings: PillSettings) -> CGSize {
        settings.expandedSize
    }

    static func expandedSize(
        settings: PillSettings,
        showingRateLimits: Bool,
        showingAgentApproval: Bool = false,
        agentTaskCount: Int = 0
    ) -> CGSize {
        var size = settings.expandedSize

        let visibleTaskCount = min(max(agentTaskCount, 0), 3)
        if visibleTaskCount > 0 {
            let taskHeight = agentTasksExpandedBaseHeight
                + CGFloat(visibleTaskCount - 1) * agentTaskRowHeightBoost
            size.height = max(size.height, min(taskHeight, PillSettings.Defaults.expandedHeightRange.upperBound))
        } else if showingRateLimits {
            size.height = rateLimitExpandedHeight
        } else if showingAgentApproval {
            size.height = max(size.height, agentApprovalExpandedMinHeight)
        } else {
            size.height = min(size.height, compactExpandedHeight)
        }

        return size
    }

    static func topCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedTopCornerRadius : collapsedTopCornerRadius
    }

    static func bottomCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedBottomCornerRadius : collapsedBottomCornerRadius
    }

}
