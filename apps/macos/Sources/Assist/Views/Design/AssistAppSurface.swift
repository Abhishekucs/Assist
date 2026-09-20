import SwiftUI

/// Themes a window's SwiftUI content. Window controllers apply the persisted
/// Appearance preference with `NSWindow.followAppearance(of:)`, so `colorScheme`
/// already reflects Light, Dark, or the live System appearance.
struct AssistAppSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: (AssistTheme) -> Content

    init(@ViewBuilder content: @escaping (AssistTheme) -> Content) {
        self.content = content
    }

    var body: some View {
        let theme = AssistTheme(colorScheme: colorScheme)
        content(theme)
            .environment(\.assistTheme, theme)
            .foregroundStyle(theme.foreground)
            .font(AssistDesignTokens.Typography.body())
            .tint(theme.accent)
    }
}
