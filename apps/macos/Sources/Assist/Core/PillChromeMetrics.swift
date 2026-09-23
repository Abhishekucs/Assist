import CoreGraphics

// Shared geometry for the capture shelf and its native window hit-testing.
enum PillChromeMetrics {
    static let collapsedTopCornerRadius = PillSettings.Defaults.collapsedTopCornerRadius
    static let collapsedBottomCornerRadius = PillSettings.Defaults.collapsedBottomCornerRadius
    static let expandedTopCornerRadius = PillSettings.Defaults.expandedTopCornerRadius
    static let expandedBottomCornerRadius = PillSettings.Defaults.expandedBottomCornerRadius
    static let topInset = PillSettings.Defaults.topInset
    /// The expanded module island: top inset 6, module tab row 30, gap 10,
    /// module content 174 (a 24pt toolbar, 8pt gap, and the 142pt capture
    /// cards), and bottom inset 14.
    static let moduleExpandedHeight: CGFloat = 234

    // The collapsed island keeps one width; short feedback labels fit without growing the chrome.
    @MainActor
    static func collapsedSize(settings: PillSettings) -> CGSize {
        settings.collapsedSize
    }

    /// Every module shares one island height, and the island widens only when
    /// the enabled module tabs need more room beside the notch.
    @MainActor
    static func expandedSize(settings: PillSettings, enabledModuleCount: Int = 1) -> CGSize {
        let preferred = settings.expandedSize
        let layout = ModuleTabLayout(tabCount: enabledModuleCount, preferredIslandWidth: preferred.width)
        return CGSize(width: layout.islandWidth, height: moduleExpandedHeight)
    }

    static func topCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedTopCornerRadius : collapsedTopCornerRadius
    }

    static func bottomCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedBottomCornerRadius : collapsedBottomCornerRadius
    }
}
