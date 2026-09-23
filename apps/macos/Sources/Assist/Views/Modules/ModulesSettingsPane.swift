import SwiftUI

/// Settings → Modules: which modules appear on the notch island.
struct ModulesSettingsPane: View {
    @ObservedObject var settings: ModuleSettings
    let screenTime: ScreenTimeTracker
    @ObservedObject var revenue: RevenueService
    @State private var isConfirmingScreenTimeReset = false

    var body: some View {
        SettingsDetailPage(
            title: "Modules",
            subtitle: "Choose what the notch island shows. Module data stays on this Mac; Revenue contacts only the providers you connect."
        ) {
            SettingsSection("Island modules") {
                ForEach(Array(AssistModule.allCases.enumerated()), id: \.element.id) { index, module in
                    if index > 0 {
                        RowDivider()
                    }
                    ModuleToggleRow(module: module, settings: settings)
                }
            }

            SettingsSection("Revenue keys") {
                ForEach(Array(RevenueProvider.allCases.enumerated()), id: \.element.id) { index, provider in
                    if index > 0 {
                        RowDivider()
                    }
                    RevenueKeyRow(provider: provider, revenue: revenue)
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

/// Adds or removes one provider's API key. A saved key is never shown again;
/// it lives only in the Keychain.
private struct RevenueKeyRow: View {
    let provider: RevenueProvider
    @ObservedObject var revenue: RevenueService
    @State private var key = ""
    @State private var errorMessage: String?
    @Environment(\.assistTheme) private var theme

    var body: some View {
        SettingsRow(provider.title, detail: errorMessage ?? provider.keyHint) {
            if revenue.isConnected(provider) {
                HStack(spacing: Tokens.Spacing.medium) {
                    HStack(spacing: Tokens.Spacing.xxSmall) {
                        HugeIcon(.check, size: Tokens.Icon.small, color: theme.foreground)
                        Text("Connected")
                            .font(Tokens.Typography.small(.medium))
                            .foregroundStyle(theme.foreground)
                    }
                    Button("Remove") {
                        revenue.removeKey(for: provider)
                    }
                    .buttonStyle(AssistButtonStyle(height: Tokens.Control.mediumHeight))
                    .help("Delete the \(provider.title) key from the Keychain")
                }
            } else {
                HStack(spacing: Tokens.Spacing.small) {
                    SecureField(provider.keyPlaceholder, text: $key)
                        .assistTextField(height: Tokens.Control.mediumHeight)
                        .frame(width: 190)
                        .accessibilityLabel("\(provider.title) API key")
                        .onSubmit(save)
                    Button("Save", action: save)
                        .buttonStyle(AssistButtonStyle(emphasis: .primary, height: Tokens.Control.mediumHeight))
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            try revenue.saveKey(key, for: provider)
            key = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
