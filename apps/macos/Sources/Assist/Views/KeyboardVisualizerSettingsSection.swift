import SwiftUI

private typealias Tokens = AssistDesignTokens

struct KeyboardVisualizerSettingsSection: View {
    @ObservedObject var controller: KeyboardSoundController
    @ObservedObject private var settings: KeyboardSoundSettings
    @Environment(\.assistTheme) private var theme

    init(controller: KeyboardSoundController) {
        self.controller = controller
        settings = controller.settings
    }

    var body: some View {
        SettingsSection("Keyboard visualizer") {
            SettingToggleRow(title: "Show keyboard while typing", detail: "Appears as you type and hides after one second of inactivity.",
                             isOn: $settings.configuration.visualizerEnabled)
            pickerRow("Keyboard design") {
                Picker("Keyboard design", selection: $settings.configuration.visualizerStyle) {
                    ForEach(KeyboardVisualizerStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
            }

            KeyboardVisualizerView(state: controller.visualizer, style: settings.configuration.visualizerStyle)
                .frame(width: KeyboardVisualizerLayout.size.width)
                .padding(.vertical, Tokens.Spacing.small)
                // The preview is centered in the group on purpose.
                .frame(maxWidth: .infinity)

            if settings.configuration.visualizerEnabled {
                pickerRow("Position") {
                    Picker("Visualizer position", selection: $settings.configuration.visualizerPosition) {
                        ForEach(KeyboardVisualizerPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                }
            }
            Text("US keyboard layout. Works with sounds off. Clicks pass through to the app underneath.")
                .font(AssistFont.caption())
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Settings.rowInset)
                .padding(.bottom, Tokens.Spacing.small)
        }
    }

    private func pickerRow<Control: View>(_ title: String, @ViewBuilder picker: () -> Control) -> some View {
        HStack {
            Text(title).font(AssistFont.label())
            Spacer()
            picker()
                .labelsHidden()
                .frame(width: Tokens.Settings.pickerWidth)
                .controlSize(.small)
        }
        .padding(.horizontal, Tokens.Settings.rowInset)
        .frame(height: Tokens.Settings.rowHeight)
    }
}
