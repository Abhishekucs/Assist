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
    private static let expandedVerticalPadding: CGFloat = 20
    private static let expandedSectionSpacing: CGFloat = 10
    private static let usageRailHeight: CGFloat = 26
    private static let taskRowHeight: CGFloat = 38
    private static let taskRowSpacing: CGFloat = 5
    private static let hiddenTaskLabelHeight: CGFloat = 12
    private static let historyHeaderHeight: CGFloat = 24
    private static let historyGalleryHeight: CGFloat = 144

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

        let taskCount = max(agentTaskCount, 0)
        let visibleTaskCount = min(taskCount, 3)
        if visibleTaskCount > 0 {
            let taskStackHeight = CGFloat(visibleTaskCount) * taskRowHeight
                + CGFloat(visibleTaskCount - 1) * taskRowSpacing
                + (taskCount > visibleTaskCount ? taskRowSpacing + hiddenTaskLabelHeight : 0)
            let usageHeight = showingRateLimits
                ? usageRailHeight + expandedSectionSpacing
                : 0
            let contentHeight = expandedVerticalPadding
                + usageHeight
                + taskStackHeight
                + expandedSectionSpacing
                + historyHeaderHeight
                + expandedSectionSpacing
                + historyGalleryHeight
            size.height = min(
                max(
                    contentHeight,
                    showingAgentApproval ? agentApprovalExpandedMinHeight : 0
                ),
                PillSettings.Defaults.expandedHeightRange.upperBound
            )
        } else if showingRateLimits {
            size.height = max(
                rateLimitExpandedHeight,
                showingAgentApproval ? agentApprovalExpandedMinHeight : 0
            )
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
