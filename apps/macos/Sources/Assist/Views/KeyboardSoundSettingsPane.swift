import SwiftUI

struct KeyboardSoundSettingsPane: View {
    @ObservedObject var controller: KeyboardSoundController
    @ObservedObject private var settings: KeyboardSoundSettings
    @Environment(\.assistTheme) private var theme
    @State private var search = ""

    private var matchingPacks: [KeyboardSoundPack] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return KeyboardSoundPack.allCases.filter {
            query.isEmpty || "\($0.title) \($0.detail)".localizedCaseInsensitiveContains(query)
        }
    }

    init(controller: KeyboardSoundController) {
        self.controller = controller
        self.settings = controller.settings
    }

    var body: some View {
        SettingsDetailPage(title: "Sounds", subtitle: "Give your everyday typing a different feel.") {
            SettingToggleRow(title: "Keyboard sounds", detail: "Play sounds as you press and release keys.",
                             isOn: $settings.configuration.enabled)

            KeyboardVisualizerSettingsSection(controller: controller)

            statusMessage

            SettingsSection("Sound pack") {
                TextField("Find a sound or switch", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .accessibilityLabel("Find a sound or switch")
                    .padding(.bottom, 8)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(matchingPacks) { pack in
                        soundPack(pack)
                    }
                }
                if matchingPacks.isEmpty {
                    Text("No sounds match your search.")
                        .font(.caption).foregroundStyle(theme.muted)
                        .padding(.vertical, 12)
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
