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
    static let size = CGSize(width: 700, height: 420)

    @ObservedObject var viewModel: LicenseActivationViewModel

    var body: some View {
        AssistAppSurface { theme in
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 9) {
                        AssistLogo(size: 28)
                        Text("Assist")
                            .font(AssistFont.title())
                    }
                    .padding(.bottom, 36)

                    HStack(spacing: 10) {
                        HugeIcon(.grid, size: 17)
                        Text("Welcome").font(AssistFont.body())
                        Spacer()
                    }
                    .padding(11)
                    .background(theme.selected, in: RoundedRectangle(cornerRadius: 10))

                    Spacer()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Made for your Mac")
                            .font(AssistFont.small(.medium))
                        Text("Capture, annotate, and keep your clipboard close.")
                            .font(AssistFont.caption())
                            .foregroundStyle(theme.muted)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .background(theme.accentSurface, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 18)
                .padding(.top, 44)
                .padding(.bottom, 22)
                .frame(width: 208)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Welcome to Assist")
                        .font(.system(size: 24, weight: .medium))
                        .padding(.bottom, 10)

                    Text("Enter the license key from your purchase receipt to get started.")
                        .font(AssistFont.body())
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("License key")
                            .font(AssistFont.small(.medium))
                        TextField("Paste your license key", text: $viewModel.licenseKey)
                            .assistTextField(height: 42)
                            .accessibilityLabel("License key")
                            .disabled(viewModel.isActivating)
                            .onSubmit { viewModel.activate() }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(AssistFont.caption())
                                .foregroundStyle(theme.dangerText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 30)

                    Spacer(minLength: 24)

                    HStack(spacing: 10) {
                        Button("Quit") { NSApp.terminate(nil) }
                            .buttonStyle(AssistButtonStyle(height: 36))
                            .disabled(viewModel.isActivating)

                        Spacer()

                        Button { viewModel.activate() } label: {
                            HStack(spacing: 8) {
                                if viewModel.isActivating {
                                    ProgressView().controlSize(.small)
                                }
                                Text(viewModel.isActivating ? "Activating…" : "Activate Assist")
                            }
                        }
                        .buttonStyle(AssistButtonStyle(emphasis: .primary, height: 36, isBusy: viewModel.isActivating))
                        .disabled(!viewModel.canActivate)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.background, in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.window))
                .padding(.vertical, 8)
                .padding(.trailing, 8)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .background(theme.sidebar)
        }
    }
}
