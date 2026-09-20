import SwiftUI

struct SettingsDialog<Content: View>: View {
    let onClose: () -> Void
    let content: Content
    @Environment(\.assistTheme) private var theme
    @State private var isEditingText = false

    init(onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content

            // A shortcut, unlike onExitCommand, fires without focus inside the
            // dialog. While a field is being edited, Esc ends editing first.
            HugeIconButton(kind: .close, tooltip: "Close settings", action: onClose)
                .keyboardShortcut(isEditingText ? nil : .cancelAction)
                .padding(.top, Tokens.Settings.closeButtonInset)
                .padding(.trailing, Tokens.Settings.closeButtonInset)
        }
        .onPreferenceChange(AssistTextFieldEditingKey.self) { isEditing in
            isEditingText = isEditing
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.window, style: .continuous))
        .shadow(color: .black.opacity(theme.isDark ? 0.28 : 0.12), radius: 28, y: 14)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
