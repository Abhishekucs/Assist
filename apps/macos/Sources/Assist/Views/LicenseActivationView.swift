import AppKit
import SwiftUI

@MainActor
final class LicenseActivationViewModel: ObservableObject {
    @Published var licenseKey = ""
    @Published var isActivating = false
    @Published var errorMessage: String?

    var onActivated: ((LicenseActivation) -> Void)?

    private let validationService: LicenseValidationService
    private let activationStore: LicenseActivationStore

    var canActivate: Bool {
        !licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isActivating
    }

    init(
        validationService: LicenseValidationService,
        activationStore: LicenseActivationStore
    ) {
        self.validationService = validationService
        self.activationStore = activationStore
    }

    func activate() {
        guard canActivate else { return }

        let key = licenseKey
        isActivating = true
        errorMessage = nil

        Task {
            do {
                let activation = try await validationService.activate(licenseKey: key)
                try activationStore.save(activation)
                onActivated?(activation)
            } catch {
                errorMessage = error.localizedDescription
                isActivating = false
            }
        }
    }
}

struct LicenseActivationView: View {
    @ObservedObject var viewModel: LicenseActivationViewModel
    private let theme = AssistTheme(colorScheme: .dark)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)

                    Text("A")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.black)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppIdentity.name)
                        .font(AssistFont.title())
                        .foregroundStyle(theme.foreground)

                    Text("License required")
                        .font(AssistFont.caption(.medium))
                        .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: 24)

            Text("Activate Assist")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(theme.foreground)

            Text("Enter the license key from your purchase receipt to open the production app.")
                .font(AssistFont.small())
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                TextField("License key", text: $viewModel.licenseKey)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.foreground)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(theme.selected, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    }
                    .disabled(viewModel.isActivating)
                    .onSubmit {
                        viewModel.activate()
                    }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AssistFont.caption(.medium))
                        .foregroundStyle(Color(hex: 0xFF6B6B))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 24)

            Spacer(minLength: 28)

            HStack(spacing: 10) {
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryActivationButtonStyle(theme: theme))
                .disabled(viewModel.isActivating)

                Button {
                    viewModel.activate()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isActivating {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.76)
                        }

                        Text(viewModel.isActivating ? "Activating" : "Activate")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActivationButtonStyle(theme: theme))
                .disabled(!viewModel.canActivate)
            }
        }
        .padding(28)
        .frame(width: 460, height: 360)
        .background(theme.background)
        .foregroundStyle(theme.foreground)
        .environment(\.assistTheme, theme)
    }
}

private struct PrimaryActivationButtonStyle: ButtonStyle {
    let theme: AssistTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AssistFont.small(.semibold))
            .foregroundStyle(Color.black)
            .frame(height: 42)
            .background(Color.white.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct SecondaryActivationButtonStyle: ButtonStyle {
    let theme: AssistTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AssistFont.small(.semibold))
            .foregroundStyle(theme.foreground)
            .frame(height: 42)
            .background(theme.selected.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            }
    }
}
