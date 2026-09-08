import SwiftUI

struct KeyboardSoundSettingsPane: View {
    @ObservedObject var controller: KeyboardSoundController
    @ObservedObject private var settings: KeyboardSoundSettings
    @Environment(\.assistTheme) private var theme

    init(controller: KeyboardSoundController) {
        self.controller = controller
        self.settings = controller.settings
    }

    var body: some View {
        SettingsDetailPage(title: "Sounds", subtitle: "Give your everyday typing a different feel.") {
            SettingToggleRow(title: "Keyboard sounds", detail: "Play sounds as you press and release keys.",
                             isOn: $settings.configuration.enabled)

            SettingsSection("Keyboard visualizer") {
                SettingToggleRow(title: "Show keyboard", detail: "Light up a floating keyboard as you type, even with sounds off.",
                                 isOn: $settings.configuration.visualizerEnabled)
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
                    Text("US keyboard layout. Clicks pass through to the app underneath.")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
            }

            statusMessage

            SettingsSection("Sound pack") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(KeyboardSoundPack.allCases) { pack in
                        soundPack(pack)
                    }
                }
            }

            SettingsSection("Playback") {
                HStack(spacing: 12) {
                    Text("Volume").font(.footnote.weight(.semibold))
                    Slider(value: $settings.configuration.volume, in: 0...1)
                        .controlSize(.small)
                        .accessibilityLabel("Keyboard sound volume")
                    Text("\(Int(settings.configuration.validated.volume * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.muted)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)

                SettingToggleRow(title: "Stereo positioning", detail: "Follow each key from left to right.",
                                 isOn: $settings.configuration.stereo)
            }

            Text("Keyboard feedback stays on your Mac. Typed text is never saved. Sounds and the visualizer pause while Assist records voice context.")
                .font(.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { controller.refresh() }
    }

    private func soundPack(_ pack: KeyboardSoundPack) -> some View {
        let selected = settings.configuration.pack == pack
        return HStack(spacing: 4) {
            Button {
                settings.configuration.pack = pack
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(pack.title).font(.footnote.weight(.semibold))
                        if selected { HugeIcon(.check, size: 12) }
                    }
                    Text(pack.detail)
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(pack.title) sound pack")
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .help("Select \(pack.title)")
            .pointingHandCursor()

            HugeIconButton(kind: .play, tooltip: "Preview \(pack.title)") {
                controller.preview(pack)
            }
            .disabled(controller.status == .recording || controller.status == .suspended)
        }
        .foregroundStyle(theme.foreground)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(selected ? theme.selected : theme.background,
                    in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.control))
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let error = controller.previewError {
            Text(error).font(.caption).foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        switch controller.status {
        case .needsPermission:
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow Input Monitoring for keyboard sounds and the visualizer in other apps. You can preview every sound pack here first.")
                    .font(.caption).foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Allow Input Monitoring") { controller.requestPermission() }
                    .controlSize(.small)
            }
        case .recording:
            Text("Paused while Assist records voice context.")
                .font(.caption).foregroundStyle(theme.muted)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(.caption).foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry") { controller.refresh() }.controlSize(.small)
            }
        case .suspended:
            Text("Paused while this Mac is inactive.")
                .font(.caption).foregroundStyle(theme.muted)
        case .off, .ready:
            EmptyView()
        }
    }
}
