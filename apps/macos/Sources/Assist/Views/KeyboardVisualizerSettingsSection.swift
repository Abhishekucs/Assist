import SwiftUI

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
                // The Assist style shares this group's card color, so the
                // preview needs its own edge.
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.medium)
                        .strokeBorder(theme.border, lineWidth: Tokens.Control.borderWidth)
                }
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
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Settings.rowInset)
                .padding(.bottom, Tokens.Spacing.small)
        }
    }

    private func pickerRow<Control: View>(_ title: String, @ViewBuilder picker: () -> Control) -> some View {
        SettingsRow(title) {
            picker()
                .labelsHidden()
                .frame(width: Tokens.Settings.pickerWidth)
                .controlSize(.small)
        }
    }
}
