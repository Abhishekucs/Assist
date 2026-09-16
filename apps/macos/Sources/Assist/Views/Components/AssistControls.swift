import SwiftUI

struct AssistButtonStyle: ButtonStyle {
    enum Emphasis { case primary, secondary }
    var emphasis: Emphasis = .secondary
    var height: CGFloat = 30
    /// Keeps a button that is disabled while it shows progress fully legible.
    var isBusy = false
    @Environment(\.assistTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AssistFont.small(.medium))
            .foregroundStyle(emphasis == .primary ? .white : theme.foreground)
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(
                emphasis == .primary ? theme.primaryButton : theme.card,
                in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.control)
            )
            .overlay {
                if emphasis == .secondary {
                    RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.control)
                        .strokeBorder(theme.border, lineWidth: 1)
                }
            }
            .opacity(opacity(isPressed: configuration.isPressed))
            .contentShape(RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.control))
            .pointingHandCursor(isEnabled: isEnabled)
    }

    private func opacity(isPressed: Bool) -> Double {
        if isBusy { return 1 }
        if !isEnabled { return 0.42 }
        return isPressed ? 0.76 : 1
    }
}

/// Plain text field chrome with a visible focus ring for keyboard users.
private struct AssistTextFieldChrome: ViewModifier {
    let height: CGFloat
    @Environment(\.assistTheme) private var theme
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.control)
        content
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, AssistDesignTokens.Spacing.large)
            .frame(height: height)
            .background(theme.control, in: shape)
            .overlay {
                shape.strokeBorder(isFocused ? theme.accent : .clear, lineWidth: 2)
            }
            .animation(AssistDesignTokens.Motion.quick, value: isFocused)
    }
}

extension View {
    func assistTextField(height: CGFloat = AssistDesignTokens.Control.fieldHeight) -> some View {
        modifier(AssistTextFieldChrome(height: height))
    }
}

struct AssistKeycap: View {
    let title: String
    @Environment(\.assistTheme) private var theme

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(theme.accentSurface, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct AssistNavigationRow: View {
    let title: String
    let icon: HugeIconKind
    var isSelected = false
    var count: Int? = nil
    let action: () -> Void
    @Environment(\.assistTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                HugeIcon(icon, size: 17, color: theme.foreground)
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                Spacer(minLength: 0)
                if let count {
                    Text(count.formatted())
                        .font(AssistFont.caption())
                        .foregroundStyle(theme.muted)
                }
            }
            .foregroundStyle(theme.foreground)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(
                isSelected ? theme.selected : (isHovered ? theme.control : .clear),
                in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
        .pointingHandCursor()
        .onHover { isHovered = $0 }
    }
}
