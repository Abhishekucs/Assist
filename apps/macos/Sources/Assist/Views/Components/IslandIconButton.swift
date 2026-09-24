import SwiftUI

/// An icon-only button on the island's black surface. It stays transparent
/// until hovered and shows its label within the island.
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
            if isHovered && isEnabled {
                IslandHoverTooltip(title: tooltip)
                    .offset(y: 28)
            }
        }
        .zIndex(isHovered ? 2 : 0)
        .onHover { isHovered = $0 }
        .animation(AssistDesignTokens.Motion.quick, value: isHovered)
    }
}
