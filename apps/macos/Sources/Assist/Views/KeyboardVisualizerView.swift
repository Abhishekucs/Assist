import SwiftUI

struct KeyboardVisualizerView: View {
    @ObservedObject var state: KeyboardVisualizerState
    @Environment(\.assistTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let gap = AssistDesignTokens.Spacing.xxSmall
            let pitch = (geometry.size.width + gap) / KeyboardVisualizerLayout.rowUnits
            VStack(spacing: gap) {
                ForEach(KeyboardVisualizerLayout.rows.indices, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(KeyboardVisualizerLayout.rows[row]) { key in
                            KeyboardVisualizerKeycap(key: key, pressed: state.pressedKeys.contains(key.code))
                                .frame(width: key.units * pitch - gap, height: 20)
                        }
                    }
                }
            }
        }
        .frame(height: 140)
        .padding(AssistDesignTokens.Spacing.small)
        .background(theme.card, in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard visualizer, US layout")
        .accessibilityValue(state.isVisible ? "Live" : "Off")
    }
}

private struct KeyboardVisualizerKeycap: View {
    let key: KeyboardVisualizerKey
    let pressed: Bool
    @Environment(\.assistTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(key.label)
            .font(.system(size: key.label.count > 1 ? 7 : 9, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(pressed ? theme.background : theme.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pressed ? theme.foreground : theme.selected,
                        in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.small))
            .offset(y: pressed && !reduceMotion ? 1 : 0)
            // Press is immediate. Only the visual release is animated; key state
            // is cleared by the release event itself, without delayed tasks.
            .animation(reduceMotion || pressed ? nil : AssistDesignTokens.Motion.quick, value: pressed)
    }
}

struct KeyboardVisualizerOverlay: View {
    @ObservedObject var state: KeyboardVisualizerState
    @ObservedObject var settings: PillSettings
    @State private var systemScheme = SystemAppearanceResolver.currentColorScheme()

    private var colorScheme: ColorScheme {
        switch settings.appAppearance {
        case .light: .light
        case .dark: .dark
        case .system: systemScheme
        }
    }

    var body: some View {
        KeyboardVisualizerView(state: state)
            .environment(\.assistTheme, AssistTheme(colorScheme: colorScheme))
            .preferredColorScheme(colorScheme)
            .onReceive(DistributedNotificationCenter.default().publisher(for: SystemAppearanceResolver.changeNotification)) { _ in
                systemScheme = SystemAppearanceResolver.currentColorScheme()
            }
    }
}
