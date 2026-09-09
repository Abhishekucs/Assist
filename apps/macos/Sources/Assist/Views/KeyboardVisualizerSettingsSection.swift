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
            HStack {
                Text("Keyboard design").font(.footnote.weight(.semibold))
                Spacer()
                Picker("Keyboard design", selection: $settings.configuration.visualizerStyle) {
                    ForEach(KeyboardVisualizerStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .frame(width: 166)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)

            KeyboardVisualizerView(state: controller.visualizer, style: settings.configuration.visualizerStyle)
                .frame(width: KeyboardVisualizerLayout.size.width)
                .padding(.vertical, 8)

            if settings.configuration.visualizerEnabled {
                HStack {
                    Text("Position").font(.footnote.weight(.semibold))
                    Spacer()
                    Picker("Visualizer position", selection: $settings.configuration.visualizerPosition) {
                        ForEach(KeyboardVisualizerPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 166)
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
            }
            Text("US keyboard layout. Works with sounds off. Clicks pass through to the app underneath.")
                .font(.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
        }
    }
}
