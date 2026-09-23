import SwiftUI

struct IslandHoverTooltip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AssistDesignTokens.Typography.caption(.semibold))
            .foregroundStyle(AssistDesignTokens.Mono.selectedForeground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, AssistDesignTokens.Spacing.small)
            .padding(.vertical, AssistDesignTokens.Spacing.xxSmall)
            .background(
                AssistDesignTokens.Mono.selectedFill,
                in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.small)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
