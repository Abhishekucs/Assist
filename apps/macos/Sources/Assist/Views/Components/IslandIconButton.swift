import SwiftUI

/// An icon-only button on the island's black surface. It stays transparent
/// until hovered and shows its tooltip as a small capsule below the icon.
struct IslandIconButton: View {
    let icon: HugeIconKind
    let tooltip: String
    var isEnabled = true
    var size: CGFloat = AssistDesignTokens.Control.iconButton
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HugeIcon(
                icon,
                size: AssistDesignTokens.Icon.regular,
                color: .white.opacity(
                    isEnabled
                        ? (isHovered ? AssistDesignTokens.Opacity.primary : AssistDesignTokens.Opacity.secondary)
                        : AssistDesignTokens.Opacity.disabled
                )
            )
                .frame(width: size, height: size)
                .background(
                    Color.white.opacity(
                        isEnabled && isHovered ? AssistDesignTokens.Opacity.hoverSurface : 0
                    ),
                    in: RoundedRectangle(
                        cornerRadius: AssistDesignTokens.Radius.control,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(tooltip)
        .pointingHandCursor(isEnabled: isEnabled)
        .overlay(alignment: .bottomTrailing) {
            if isHovered {
                IslandTooltip(text: tooltip)
                    .offset(y: AssistDesignTokens.Spacing.xxxLarge + AssistDesignTokens.Spacing.xxxSmall)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
        .zIndex(isHovered ? 20 : 0)
        .onHover { isHovered = $0 }
        .animation(AssistDesignTokens.Motion.quick, value: isHovered)
    }
}

/// The island's tooltip: dark text on a white capsule.
struct IslandTooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AssistDesignTokens.Palette.ink)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, AssistDesignTokens.Spacing.small)
            .frame(height: AssistDesignTokens.Control.tooltipHeight)
            .background(AssistDesignTokens.Palette.paper, in: Capsule())
            .allowsHitTesting(false)
    }
}
