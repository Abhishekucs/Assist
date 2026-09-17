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

/// A single focused form: heading, license key, and the two actions.
struct LicenseActivationView: View {
    /// The window's size until an error message needs more height.
    static let minimumSize = CGSize(width: 480, height: 340)
    static let errorLineLimit = 4

    @ObservedObject var viewModel: LicenseActivationViewModel

    var body: some View {
        AssistAppSurface { theme in
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome to Assist")
                    .font(Tokens.Typography.largeTitle)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, Tokens.Spacing.medium)

                Text("Enter the license key from your purchase receipt to get started.")
                    .font(Tokens.Typography.body())
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 9) {
                    Text("License key")
                        .font(Tokens.Typography.small(.medium))
                    TextField("Paste your license key", text: $viewModel.licenseKey)
                        .assistTextField(height: Tokens.Control.heroHeight)
                        .accessibilityLabel("License key")
                        .disabled(viewModel.isActivating)
                        // A focused field keeps Return for itself, so the Activate
                        // button's default-action shortcut only fires when the
                        // field isn't focused; each path covers one case.
                        .onSubmit { viewModel.activate() }

                    if let errorMessage = viewModel.errorMessage {
                        // Server errors can be long; the window grows by at most
                        // a few lines, and the full text stays available.
                        Text(errorMessage)
                            .font(Tokens.Typography.caption())
                            .foregroundStyle(theme.dangerText)
                            .lineLimit(Self.errorLineLimit)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                            .help(errorMessage)
                            .accessibilityLabel(errorMessage)
                            .textSelection(.enabled)
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
                                ProgressView()
                                    .controlSize(.small)
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
            .padding(.top, Tokens.Spacing.large)
            .padding(.bottom, 32)
            .titleBarSafeArea()
            // Fixed width; the height grows past the minimum only when the
            // content (such as a long server error) needs it.
            .frame(width: Self.minimumSize.width)
            .frame(minHeight: Self.minimumSize.height, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .background(theme.background)
        }
    }
}
