import SwiftUI

/// Settings → Modules: which modules appear on the notch island.
struct ModulesSettingsPane: View {
    @ObservedObject var settings: ModuleSettings
    let screenTime: ScreenTimeTracker
    @State private var isConfirmingScreenTimeReset = false

    var body: some View {
        SettingsDetailPage(
            title: "Modules",
            subtitle: "Choose what the notch island shows. Every module keeps its data on this Mac."
        ) {
            SettingsSection("Island modules") {
                ForEach(Array(AssistModule.allCases.enumerated()), id: \.element.id) { index, module in
                    if index > 0 {
                        RowDivider()
                    }
                    ModuleToggleRow(module: module, settings: settings)
                }
            }

            SettingsSection("Screen Time") {
                SettingsRow(
                    "Clear screen time history",
                    detail: "Removes the recorded time for every app. Tracking continues while the module is on."
                ) {
                    Button("Clear…") {
                        isConfirmingScreenTimeReset = true
                    }
                    .buttonStyle(AssistButtonStyle())
                }
            }
        }
        .confirmationDialog(
            "Clear screen time history?",
            isPresented: $isConfirmingScreenTimeReset
        ) {
            Button("Clear History", role: .destructive) {
                screenTime.reset()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

private struct ModuleToggleRow: View {
    let module: AssistModule
    @ObservedObject var settings: ModuleSettings
    @Environment(\.assistTheme) private var theme

    var body: some View {
        SettingsRow(module.title, detail: module.detail) {
            HStack(spacing: Tokens.Spacing.medium) {
                HugeIcon(module.icon, size: Tokens.Icon.medium, color: theme.muted)
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .accessibilityLabel(module.title)
                    .toggleStyle(.switch)
                    .tint(theme.accent)
                    .controlSize(.small)
                    .disabled(module.isRequired)
                    .pointingHandCursor(isEnabled: !module.isRequired)
            }
        }
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { settings.isEnabled(module) },
            set: { settings.setEnabled(module, $0) }
        )
    }
}
