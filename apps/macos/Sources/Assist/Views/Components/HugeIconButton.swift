import SwiftUI

struct HugeIconButton: View {
    let kind: HugeIconKind
    let tooltip: String
    let action: () -> Void
    @Environment(\.assistTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HugeIcon(kind, size: AssistDesignTokens.Icon.feedback, color: theme.muted)
                .frame(width: AssistDesignTokens.Control.largeIconButton, height: AssistDesignTokens.Control.largeIconButton)
                .background(
                    backgroundColor,
                    in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.iconButton, style: .continuous)
                )
                .opacity(isEnabled ? 1 : AssistDesignTokens.Opacity.disabledControl)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
        .pointingHandCursor(isEnabled: isEnabled)
        .onHover { isHovered = $0 }
        .animation(AssistDesignTokens.Motion.quick, value: isHovered)
    }

    private var backgroundColor: Color {
        isHovered && isEnabled ? theme.selected.opacity(theme.isDark ? 0.62 : 0.78) : .clear
    }
}
