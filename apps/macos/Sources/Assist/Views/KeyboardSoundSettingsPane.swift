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
            SettingsSection("Keyboard feedback") {
                SettingToggleRow(title: "Keyboard sounds", detail: "Play sounds as you press and release keys.",
                                 isOn: $settings.configuration.enabled)
            }

            KeyboardVisualizerSettingsSection(controller: controller)

            statusMessage

            SettingsSection("Sound pack") {
                SettingsControlGroup {
                    soundPackPicker
                }
            }

            SettingsSection("Playback") {
                SettingsRow("Volume") {
                    HStack(spacing: Tokens.Spacing.large) {
                        Slider(value: $settings.configuration.volume, in: 0...1)
                            .controlSize(.small)
                            .accessibilityLabel("Keyboard sound volume")
                        Text("\(Int(settings.configuration.validated.volume * 100))%")
                            .font(Tokens.Typography.caption().monospacedDigit())
                            .foregroundStyle(theme.muted)
                            .frame(width: 34, alignment: .trailing)
                    }
                    // The slider takes the row's free width.
                    .frame(maxWidth: .infinity)
                }

                SettingToggleRow(title: "Stereo positioning", detail: "Follow each key from left to right.",
                                 isOn: $settings.configuration.stereo)
            }

            Text("Keyboard feedback stays on your Mac. Typed text is never saved. Sounds and the visualizer pause while Assist records voice context.")
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { controller.refresh() }
    }

    private var soundPackPicker: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
            TextField("Find a sound or switch", text: $search)
                .assistTextField()
                .accessibilityLabel("Find a sound or switch")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Tokens.Spacing.small
            ) {
                ForEach(matchingPacks) { pack in
                    soundPack(pack)
                }
            }
            if matchingPacks.isEmpty {
                Text("No sounds match your search.")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(theme.muted)
                    .padding(.vertical, Tokens.Spacing.large)
            }
        }
    }

    private func soundPack(_ pack: KeyboardSoundPack) -> some View {
        let selected = settings.configuration.pack == pack
        return HStack(spacing: Tokens.Spacing.xxSmall) {
            Button {
                settings.configuration.pack = pack
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: Tokens.Spacing.xSmall) {
                        Text(pack.title).font(Tokens.Typography.label(selected ? .medium : .regular))
                        if selected { HugeIcon(.check, size: Tokens.Icon.small, color: theme.accent) }
                    }
                    Text(pack.detail)
                        .font(Tokens.Typography.caption())
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
        .padding(.leading, Tokens.Spacing.large)
        .padding(.trailing, Tokens.Spacing.xSmall)
        .padding(.vertical, Tokens.Spacing.small)
        .assistOptionTile(isSelected: selected)
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let error = controller.previewError {
            Text(error)
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        switch controller.status {
        case .needsPermission:
            VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                Text("Allow Input Monitoring for keyboard sounds and the visualizer in other apps. You can preview every sound pack here first.")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Allow Input Monitoring") { controller.requestPermission() }
                    .buttonStyle(AssistButtonStyle())
            }
        case .recording:
            Text("Paused while Assist records voice context.")
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
        case let .failed(message):
            VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                Text(message)
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry") { controller.refresh() }
                    .buttonStyle(AssistButtonStyle())
            }
        case .suspended:
            Text("Paused while this Mac is inactive.")
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
        case .off, .ready:
            EmptyView()
        }
    }
}
