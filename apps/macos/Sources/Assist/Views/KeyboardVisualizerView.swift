import SwiftUI

struct KeyboardVisualizerView: View {
    @ObservedObject var state: KeyboardVisualizerState
    var style: KeyboardVisualizerStyle = .assist
    @Environment(\.assistTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let gap = KeyboardVisualizerLayout.keyGap
            let pitch = (geometry.size.width + gap) / KeyboardVisualizerLayout.rowUnits
            VStack(spacing: gap) {
                ForEach(KeyboardVisualizerLayout.rows.indices, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(KeyboardVisualizerLayout.rows[row]) { key in
                            KeyboardVisualizerKeycap(key: key, pressed: state.pressedKeys.contains(key.code), style: style)
                                .frame(width: key.units * pitch - gap, height: KeyboardVisualizerLayout.keyHeight)
                        }
                    }
                }
            }
        }
        .frame(height: KeyboardVisualizerLayout.contentHeight)
        .padding(KeyboardVisualizerLayout.inset)
        .background(style == .assist ? theme.card : Color.black.opacity(0.8),
                    in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard visualizer, US layout")
        .accessibilityValue(state.isVisible ? "Live" : "Off")
    }
}

private struct KeyboardVisualizerKeycap: View {
    let key: KeyboardVisualizerKey
    let pressed: Bool
    let style: KeyboardVisualizerStyle
    @Environment(\.assistTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = KeyboardVisualizerPalette(style: style)
        let fill = style == .assist ? theme.selected : Color(hex: palette.fill(for: key.code))
        let text = style == .assist ? theme.muted : Color(hex: palette.text(for: key.code))
        let pressedFill = style == .assist ? theme.foreground : text
        let pressedText = style == .assist ? theme.background : fill
        ZStack {
            if style != .assist {
                RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.small)
                    .fill(fill.opacity(0.45))
                    .offset(y: 1)
            }
            Text(key.label)
            .font(.system(size: key.label.count > 1 ? 7 : 9, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(pressed ? pressedText : text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(pressed ? pressedFill : fill,
                        in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.small))
            .offset(y: pressed && !reduceMotion ? 1 : 0)
        }
            // Press is immediate. Only the visual release is animated; key state
            // is cleared by the release event itself, without delayed tasks.
            .animation(reduceMotion || pressed ? nil : AssistDesignTokens.Motion.quick, value: pressed)
    }
}

struct KeyboardVisualizerOverlay: View {
    @ObservedObject var state: KeyboardVisualizerState
    @ObservedObject var settings: PillSettings
    @ObservedObject var soundSettings: KeyboardSoundSettings
    @State private var systemScheme = SystemAppearanceResolver.currentColorScheme()

    private var colorScheme: ColorScheme {
        switch settings.appAppearance {
        case .light: .light
        case .dark: .dark
        case .system: systemScheme
        }
    }

    var body: some View {
        KeyboardVisualizerView(state: state, style: soundSettings.configuration.visualizerStyle)
            .environment(\.assistTheme, AssistTheme(colorScheme: colorScheme))
            .preferredColorScheme(colorScheme)
            .onReceive(DistributedNotificationCenter.default().publisher(for: SystemAppearanceResolver.changeNotification)) { _ in
                systemScheme = SystemAppearanceResolver.currentColorScheme()
            }
    }
}
