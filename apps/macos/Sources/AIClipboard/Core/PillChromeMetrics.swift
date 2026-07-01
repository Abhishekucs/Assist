import CoreGraphics

enum PillChromeMetrics {
    static let collapsedSize = CGSize(width: 232, height: 30)
    static let expandedSize = CGSize(width: 560, height: 238)
    static let collapsedTopCornerRadius: CGFloat = 6
    static let collapsedBottomCornerRadius: CGFloat = 14
    static let expandedTopCornerRadius: CGFloat = 19
    static let expandedBottomCornerRadius: CGFloat = 24
    static let topInset: CGFloat = 0

    static func topCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedTopCornerRadius : collapsedTopCornerRadius
    }

    static func bottomCornerRadius(forExpandedState isExpanded: Bool) -> CGFloat {
        isExpanded ? expandedBottomCornerRadius : collapsedBottomCornerRadius
    }

    static func windowSize(forChromeSize chromeSize: CGSize) -> CGSize {
        chromeSize
    }
}
