import CoreGraphics
import Foundation

enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }
}

final class PillSettings: ObservableObject {
    enum Defaults {
        static let collapsedSize = CGSize(width: 268, height: 30)
        static let expandedSize = CGSize(width: 560, height: 300)
        static let collapsedWidthRange: ClosedRange<CGFloat> = 180...360
        static let collapsedHeightRange: ClosedRange<CGFloat> = 26...42
        static let expandedWidthRange: ClosedRange<CGFloat> = 440...760
        static let expandedHeightRange: ClosedRange<CGFloat> = 210...400
        static let collapsedTopCornerRadius: CGFloat = 6
        static let collapsedBottomCornerRadius: CGFloat = 14
        static let expandedTopCornerRadius: CGFloat = 19
        static let expandedBottomCornerRadius: CGFloat = 24
        static let topInset: CGFloat = 0
    }

    @Published var collapsedWidth: CGFloat {
        didSet { persist(collapsedWidth, for: Keys.collapsedWidth) }
    }
    @Published var collapsedHeight: CGFloat {
        didSet { persist(collapsedHeight, for: Keys.collapsedHeight) }
    }
    @Published var expandedWidth: CGFloat {
        didSet { persist(expandedWidth, for: Keys.expandedWidth) }
    }
    @Published var expandedHeight: CGFloat {
        didSet { persist(expandedHeight, for: Keys.expandedHeight) }
    }
    @Published var openOnHover: Bool {
        didSet { defaults.set(openOnHover, forKey: Keys.openOnHover) }
    }
    @Published var followPointerDisplay: Bool {
        didSet { defaults.set(followPointerDisplay, forKey: Keys.followPointerDisplay) }
    }
    @Published var showLoadingBorder: Bool {
        didSet { defaults.set(showLoadingBorder, forKey: Keys.showLoadingBorder) }
    }
    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }
    @Published var showClaudeCodeRateLimit: Bool {
        didSet { defaults.set(showClaudeCodeRateLimit, forKey: Keys.showClaudeCodeRateLimit) }
    }
    @Published var showCodexRateLimit: Bool {
        didSet { defaults.set(showCodexRateLimit, forKey: Keys.showCodexRateLimit) }
    }
    @Published var codexAgentIntegrationEnabled: Bool {
        didSet { defaults.set(codexAgentIntegrationEnabled, forKey: Keys.codexAgentIntegrationEnabled) }
    }
    @Published var downloadUpdatesAutomatically: Bool {
        didSet { defaults.set(downloadUpdatesAutomatically, forKey: Keys.downloadUpdatesAutomatically) }
    }
    @Published var appAppearance: AppAppearance {
        didSet { defaults.set(appAppearance.rawValue, forKey: Keys.appAppearance) }
    }

    private let defaults: UserDefaults

    var collapsedSize: CGSize {
        CGSize(
            width: collapsedWidth.clamped(to: Defaults.collapsedWidthRange),
            height: collapsedHeight.clamped(to: Defaults.collapsedHeightRange)
        )
    }

    var expandedSize: CGSize {
        CGSize(
            width: expandedWidth.clamped(to: Defaults.expandedWidthRange),
            height: expandedHeight.clamped(to: Defaults.expandedHeightRange)
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        collapsedWidth = Self.cgFloat(for: Keys.collapsedWidth, default: Defaults.collapsedSize.width, defaults: defaults)
        collapsedHeight = Self.cgFloat(for: Keys.collapsedHeight, default: Defaults.collapsedSize.height, defaults: defaults)
        expandedWidth = Self.cgFloat(for: Keys.expandedWidth, default: Defaults.expandedSize.width, defaults: defaults)
        expandedHeight = Self.cgFloat(for: Keys.expandedHeight, default: Defaults.expandedSize.height, defaults: defaults)
        openOnHover = Self.bool(for: Keys.openOnHover, default: true, defaults: defaults)
        followPointerDisplay = Self.bool(for: Keys.followPointerDisplay, default: true, defaults: defaults)
        showLoadingBorder = Self.bool(for: Keys.showLoadingBorder, default: true, defaults: defaults)
        showMenuBarIcon = Self.bool(for: Keys.showMenuBarIcon, default: true, defaults: defaults)
        showClaudeCodeRateLimit = Self.bool(for: Keys.showClaudeCodeRateLimit, default: true, defaults: defaults)
        showCodexRateLimit = Self.bool(for: Keys.showCodexRateLimit, default: true, defaults: defaults)
        codexAgentIntegrationEnabled = Self.bool(
            for: Keys.codexAgentIntegrationEnabled,
            default: false,
            defaults: defaults
        )
        downloadUpdatesAutomatically = Self.bool(for: Keys.downloadUpdatesAutomatically, default: true, defaults: defaults)
        appAppearance = Self.appearance(for: Keys.appAppearance, default: .system, defaults: defaults)
    }

    func resetIslandShape() {
        collapsedWidth = Defaults.collapsedSize.width
        collapsedHeight = Defaults.collapsedSize.height
        expandedWidth = Defaults.expandedSize.width
        expandedHeight = Defaults.expandedSize.height
    }

    private func persist(_ value: CGFloat, for key: String) {
        defaults.set(Double(value), forKey: key)
    }

    private static func cgFloat(for key: String, default defaultValue: CGFloat, defaults: UserDefaults) -> CGFloat {
        guard let number = defaults.object(forKey: key) as? NSNumber else { return defaultValue }
        return CGFloat(number.doubleValue)
    }

    private static func bool(for key: String, default defaultValue: Bool, defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private static func appearance(for key: String, default defaultValue: AppAppearance, defaults: UserDefaults) -> AppAppearance {
        guard let value = defaults.string(forKey: key),
              let appearance = AppAppearance(rawValue: value) else {
            return defaultValue
        }

        return appearance
    }
}

private enum Keys {
    static let collapsedWidth = "pill.collapsedWidth"
    static let collapsedHeight = "pill.collapsedHeight"
    static let expandedWidth = "pill.expandedWidth"
    static let expandedHeight = "pill.expandedHeight"
    static let openOnHover = "pill.openOnHover"
    static let followPointerDisplay = "pill.followPointerDisplay"
    static let showLoadingBorder = "pill.showLoadingBorder"
    static let showMenuBarIcon = "app.showMenuBarIcon"
    static let showClaudeCodeRateLimit = "rateLimits.showClaudeCode"
    static let showCodexRateLimit = "rateLimits.showCodex"
    static let codexAgentIntegrationEnabled = "agents.codex.enabled"
    static let downloadUpdatesAutomatically = "updates.downloadAutomatically"
    static let appAppearance = "app.appearance"
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
