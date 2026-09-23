import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Revenue module: sales today, over 7 days, and over 30 days from the
/// payment providers connected in Settings → Modules.
struct RevenueModuleView: View {
    @ObservedObject var service: RevenueService
    @ObservedObject var viewModel: PillViewModel

    private static let providerColumnWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Revenue", detail: updatedText)
            } trailing: {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    if service.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing")
                    }
                    if !service.connectedProviders.isEmpty {
                        IslandIconButton(
                            icon: .refresh,
                            tooltip: "Refresh revenue",
                            isEnabled: !service.isRefreshing,
                            size: Tokens.Control.compactHeight
                        ) {
                            service.refresh(force: true)
                        }
                    }
                }
            }

            Group {
                if service.connectedProviders.isEmpty {
                    IslandEmptyState(
                        icon: .revenue,
                        title: "Connect a payment provider",
                        message: "Add a read-only Stripe, Polar, or Dodo Payments key in Settings → Modules. Keys stay in your Keychain."
                    ) {
                        IslandTextButton(title: "Open Assist", icon: .key) {
                            viewModel.openControls()
                        }
                    }
                } else {
                    HStack(spacing: Tokens.Spacing.small) {
                        ForEach(RevenueWindow.allCases) { window in
                            RevenueTile(window: window, totals: service.summary?.totals[window])
                        }
                        providerColumn
                            .frame(width: Self.providerColumnWidth)
                    }
                }
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
        .onAppear {
            service.start()
        }
        .onDisappear {
            service.stop()
        }
    }

    private var providerColumn: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            Text("Last 30 days")
                .font(Tokens.Typography.caption(.semibold))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))

            ForEach(service.connectedProviders) { provider in
                VStack(alignment: .leading, spacing: 0) {
                    Text(provider.title)
                        .font(Tokens.Typography.caption(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                    if let error = service.errors[provider] {
                        Text(error)
                            .font(Tokens.Typography.caption())
                            .foregroundStyle(AssistDesignTokens.Palette.warning)
                            .lineLimit(2)
                    } else {
                        Text(amountText(service.summary?.providerTotals[provider]))
                            .font(Tokens.Typography.footnote(.semibold).monospacedDigit())
                            .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
    }

    private var updatedText: String? {
        guard let lastUpdated = service.lastUpdated else { return nil }
        return "Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))"
    }

    private func amountText(_ totals: RevenueTotals?) -> String {
        guard let totals, let currency = totals.currencies.first else {
            return service.summary == nil ? "—" : "No sales"
        }
        return MoneyFormatting.format(minor: totals.amounts[currency] ?? 0, currency: currency)
    }
}

private struct RevenueTile: View {
    let window: RevenueWindow
    let totals: RevenueTotals?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
            Text(window.title)
                .font(Tokens.Typography.caption(.medium))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))

            Text(primaryAmount)
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.top, Tokens.Spacing.xxSmall)

            Text(detail)
                .font(Tokens.Typography.caption())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
        .accessibilityElement(children: .combine)
    }

    private var primaryAmount: String {
        guard let totals else { return "—" }
        guard let currency = totals.currencies.first else {
            return MoneyFormatting.format(minor: 0, currency: Locale.current.currency?.identifier ?? "USD")
        }
        return MoneyFormatting.format(minor: totals.amounts[currency] ?? 0, currency: currency)
    }

    /// The sale count, and any other currencies, which are never converted.
    private var detail: String {
        guard let totals else { return "Loading…" }
        let sales = totals.count == 1 ? "1 sale" : "\(totals.count) sales"
        let others = totals.currencies.dropFirst().map { currency in
            "+ \(MoneyFormatting.format(minor: totals.amounts[currency] ?? 0, currency: currency))"
        }
        return ([sales] + others).joined(separator: "\n")
    }
}
