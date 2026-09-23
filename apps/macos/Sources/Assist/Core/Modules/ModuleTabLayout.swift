import CoreGraphics

/// Places module tabs on both sides of the camera housing, so no tab sits
/// behind the notch. Tabs fill the leading side first; the rest share the
/// trailing side with the Open Assist action. When they do
/// not fit, the island grows just enough to hold them.
struct ModuleTabLayout: Equatable {
    static let tabWidth: CGFloat = 26
    static let tabSpacing: CGFloat = 2
    /// Space between trailing tabs and the island actions.
    static let groupSpacing: CGFloat = 6
    static let actionCount = 1
    /// Horizontal inset of island content, matching the capture shelf.
    static let sideInset: CGFloat = 30
    /// Wider than the camera housing on current MacBooks, so tabs stay visible.
    static let notchClearance: CGFloat = 210

    let leadingCount: Int
    let trailingCount: Int
    /// The island width that fits every tab, never narrower than requested.
    let islandWidth: CGFloat

    init(tabCount: Int, preferredIslandWidth: CGFloat) {
        let count = max(tabCount, 0)
        let preferredSide = Self.sideWidth(forIslandWidth: preferredIslandWidth)
        let leading = min(count, Self.capacity(forWidth: preferredSide))
        let trailing = count - leading

        let trailingWidth = Self.rowWidth(itemCount: trailing)
            + (trailing > 0 ? Self.groupSpacing : 0)
            + Self.rowWidth(itemCount: Self.actionCount)
        let requiredSide = max(Self.rowWidth(itemCount: leading), trailingWidth)
        let requiredIsland = 2 * (requiredSide + Self.sideInset) + Self.notchClearance

        leadingCount = leading
        trailingCount = trailing
        islandWidth = max(preferredIslandWidth, requiredIsland.rounded(.up))
    }

    static func sideWidth(forIslandWidth width: CGFloat) -> CGFloat {
        max((width - notchClearance) / 2 - sideInset, 0)
    }

    /// How many tabs fit in a row of the given width.
    static func capacity(forWidth width: CGFloat) -> Int {
        guard width >= tabWidth else { return 0 }
        return Int(((width + tabSpacing) / (tabWidth + tabSpacing)).rounded(.down))
    }

    /// The width of a row of tab-sized items.
    static func rowWidth(itemCount: Int) -> CGFloat {
        guard itemCount > 0 else { return 0 }
        return CGFloat(itemCount) * tabWidth + CGFloat(itemCount - 1) * tabSpacing
    }
}
