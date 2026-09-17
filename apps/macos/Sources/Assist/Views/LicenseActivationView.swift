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

private typealias Tokens = AssistDesignTokens

/// A single focused form: heading, license key, and the two actions.
struct LicenseActivationView: View {
    static let size = CGSize(width: 480, height: 340)

    @ObservedObject var viewModel: LicenseActivationViewModel

    var body: some View {
        AssistAppSurface { theme in
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome to Assist")
                    .font(AssistFont.largeTitle())
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, Tokens.Spacing.medium)

                Text("Enter the license key from your purchase receipt to get started.")
                    .font(AssistFont.body())
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 9) {
                    Text("License key")
                        .font(AssistFont.small(.medium))
                    TextField("Paste your license key", text: $viewModel.licenseKey)
                        .assistTextField(height: Tokens.Control.heroHeight)
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

                Spacer(minLength: Tokens.Spacing.xxxLarge)

                HStack(spacing: Tokens.Spacing.medium) {
                    Button("Quit") { NSApp.terminate(nil) }
                        .buttonStyle(AssistButtonStyle(height: Tokens.Control.largeHeight))
                        .disabled(viewModel.isActivating)

                    Spacer()

                    Button { viewModel.activate() } label: {
                        HStack(spacing: Tokens.Spacing.small) {
                            if viewModel.isActivating {
                                ProgressView().controlSize(.small)
                            }
                            Text(viewModel.isActivating ? "Activating…" : "Activate Assist")
                        }
                    }
                    .buttonStyle(
                        AssistButtonStyle(
                            emphasis: .primary,
                            height: Tokens.Control.largeHeight,
                            isBusy: viewModel.isActivating
                        )
                    )
                    .disabled(!viewModel.canActivate)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 32)
            // Clears the close button in the transparent title bar.
            .padding(.top, 44)
            .padding(.bottom, 32)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
            .background(theme.background)
        }
    }
}
