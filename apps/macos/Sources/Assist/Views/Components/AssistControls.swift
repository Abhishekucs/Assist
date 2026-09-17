import SwiftUI

private typealias Tokens = AssistDesignTokens

struct AssistButtonStyle: ButtonStyle {
    enum Emphasis { case primary, secondary }
    var emphasis: Emphasis = .secondary
    var height: CGFloat = Tokens.Control.regularHeight
    /// Keeps a button that is disabled while it shows progress fully legible.
    var isBusy = false
    @Environment(\.assistTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.control)
        configuration.label
            .font(Tokens.Typography.small(.medium))
            .foregroundStyle(emphasis == .primary ? theme.primaryButtonForeground : theme.foreground)
            // Controls inside the label, such as a progress spinner, render for
            // the fill behind them rather than for the window.
            .environment(\.colorScheme, emphasis == .primary ? theme.primaryButtonContentScheme : theme.colorScheme)
            .padding(.horizontal, Tokens.Spacing.xLarge)
            .frame(height: height)
            .background(emphasis == .primary ? theme.primaryButton : theme.card, in: shape)
            .overlay {
                if emphasis == .secondary {
                    shape.strokeBorder(theme.controlBorder, lineWidth: Tokens.Control.borderWidth)
                }
            }
            .opacity(opacity(isPressed: configuration.isPressed))
            .contentShape(shape)
            .pointingHandCursor(isEnabled: isEnabled)
    }

    private func opacity(isPressed: Bool) -> Double {
        if isBusy { return 1 }
        if !isEnabled { return Tokens.Opacity.disabledControl }
        return isPressed ? Tokens.Opacity.pressedControl : 1
    }
}

/// Plain text field chrome: an outlined box that focuses the field anywhere
/// inside it and shows an accent ring while focused. When disabled, only the
/// box dims; AppKit already dims the field's text.
private struct AssistTextFieldChrome: ViewModifier {
    let height: CGFloat
    @Environment(\.assistTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.control)
        content
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, Tokens.Spacing.large)
            .frame(height: height)
            .background(theme.control.opacity(chromeOpacity), in: shape)
            .overlay {
                shape.strokeBorder(
                    (isFocused ? theme.accent : theme.controlBorder).opacity(chromeOpacity),
                    lineWidth: isFocused ? Tokens.Control.focusRingWidth : Tokens.Control.borderWidth
                )
            }
            // Only the text line itself is an AppKit field, so the padded box
            // needs its own tap target to focus the field.
            .contentShape(shape)
            .onTapGesture { isFocused = true }
            .animation(Tokens.Motion.quick, value: isFocused)
    }

    private var chromeOpacity: Double {
        isEnabled ? 1 : Tokens.Opacity.disabledControl
    }
}

extension View {
    func assistTextField(height: CGFloat = Tokens.Control.largeHeight) -> some View {
        modifier(AssistTextFieldChrome(height: height))
    }
}

/// Option tile chrome: a filled, outlined box that turns lavender with an
/// accent outline when selected. Callers add a non-color selection cue, such
/// as a check mark.
private struct AssistOptionTile: ViewModifier {
    let isSelected: Bool
    @Environment(\.assistTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
        content
            .background(isSelected ? theme.accentSurface : theme.control, in: shape)
            .overlay {
                shape.strokeBorder(
                    isSelected ? theme.accent : theme.controlBorder,
                    lineWidth: Tokens.Control.borderWidth
                )
            }
    }
}

extension View {
    func assistOptionTile(isSelected: Bool) -> some View {
        modifier(AssistOptionTile(isSelected: isSelected))
    }
}

/// The keys of a shortcut, as keycaps.
struct AssistKeycapRow: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: Tokens.Spacing.xSmall) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                AssistKeycap(title: key)
            }
        }
    }
}

struct AssistKeycap: View {
    let title: String
    @Environment(\.assistTheme) private var theme

    var body: some View {
        Text(title)
            .font(Tokens.Typography.keycap)
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(theme.accentSurface, in: RoundedRectangle(cornerRadius: Tokens.Radius.keycap))
    }
}

/// A sidebar navigation row. Selection adds weight and an accent icon, not
/// only a background tint.
struct AssistNavigationRow: View {
    let title: String
    let icon: HugeIconKind
    var isSelected = false
    var count: Int? = nil
    let action: () -> Void
    @Environment(\.assistTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.medium) {
                HugeIcon(icon, size: Tokens.Icon.navigation, color: isSelected ? theme.accent : theme.foreground)
                Text(title)
                    .font(Tokens.Typography.label(isSelected ? .medium : .regular))
                Spacer(minLength: 0)
                if let count {
                    Text(count.formatted())
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(theme.muted)
                }
            }
            .foregroundStyle(theme.foreground)
            .padding(.horizontal, Tokens.AppLayout.sidebarInset)
            .frame(height: Tokens.AppLayout.navigationRowHeight)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: Tokens.Radius.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor(isEnabled: isEnabled)
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if isSelected { return theme.selectedFill }
        return isHovered && isEnabled ? theme.hoverFill : .clear
    }
}
