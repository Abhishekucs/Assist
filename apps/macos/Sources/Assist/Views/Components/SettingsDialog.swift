import SwiftUI

struct SettingsDialog<Content: View>: View {
    let onClose: () -> Void
    let content: Content
    @Environment(\.assistTheme) private var theme

    init(onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content

            Button(action: onClose) {
                HugeIcon(.close, size: 11, color: theme.muted)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close settings")
            .accessibilityLabel("Close settings")
            .pointingHandCursor()
            .padding(.top, 8)
            .padding(.trailing, 9)
        }
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border.opacity(theme.isDark ? 0.7 : 1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.32 : 0.16), radius: 34, y: 18)
    }
}
