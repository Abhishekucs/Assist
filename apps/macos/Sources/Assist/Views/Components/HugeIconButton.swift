import SwiftUI

struct HugeIconButton: View {
    let kind: HugeIconKind
    let tooltip: String
    let action: () -> Void
    @Environment(\.assistTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HugeIcon(kind, size: 18, color: theme.muted)
                .frame(width: 34, height: 34)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var backgroundColor: Color {
        isHovered ? theme.selected.opacity(theme.isDark ? 0.62 : 0.78) : .clear
    }
}
