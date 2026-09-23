import Charts
import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

struct RevenueModuleView: View {
    @ObservedObject var service: RevenueService
    @ObservedObject var viewModel: PillViewModel
    @State private var preferredCurrency: String?
    @State private var showsProviders = false

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Revenue", detail: updatedText)
            } trailing: {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    if !service.connectedProviders.isEmpty {
                        IslandTextButton(title: showsProviders ? "Totals" : "Providers") {
                            showsProviders.toggle()
                        }
                        .accessibilityLabel(showsProviders ? "Show revenue totals" : "Show provider revenue")
                    }
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
                        message: "Add a read-only Stripe, Polar, or Dodo Payments key in Assist → Revenue. Keys stay in your Keychain."
                    ) {
                        IslandTextButton(title: "Open Assist", icon: .key) {
                            viewModel.openControls()
                        }
                    }
                } else {
                    HStack(spacing: Tokens.Spacing.small) {
                        trendColumn
                            .frame(maxWidth: .infinity)
                        Group {
                            if showsProviders {
                                providerDetail
                            } else {
                                totalsSummary
                            }
                        }
                        .frame(width: 190)
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

    private var availableCurrencies: [String] {
        (service.summary?.totals[.month]?.amounts.keys ?? Dictionary<String, Int64>().keys).sorted()
    }

    private var selectedCurrency: String? {
        if let preferredCurrency, availableCurrencies.contains(preferredCurrency) {
            return preferredCurrency
        }
        if let local = Locale.current.currency?.identifier, availableCurrencies.contains(local) {
            return local
        }
        return availableCurrencies.first
    }

    private var trendColumn: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
            HStack(spacing: Tokens.Spacing.xxSmall) {
                Text("Daily revenue")
                    .font(Tokens.Typography.caption(.semibold))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                Spacer(minLength: 0)
                if let selectedCurrency {
                    if availableCurrencies.count > 1 {
                        Menu {
                            ForEach(availableCurrencies, id: \.self) { currency in
                                Button(currency) { preferredCurrency = currency }
                            }
                        } label: {
                            Text(selectedCurrency)
                                .font(Tokens.Typography.caption(.semibold))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .accessibilityLabel("Revenue currency, \(selectedCurrency)")
                    } else {
                        Text(selectedCurrency)
                            .font(Tokens.Typography.caption(.semibold))
                    }
                }
            }

            if service.summary == nil {
                chartMessage("Loading revenue…")
            } else if service.errors.count == service.connectedProviders.count {
                chartMessage("Revenue unavailable")
            } else if let currency = selectedCurrency, let summary = service.summary {
                let points = summary.dailyAmounts(for: currency, now: service.lastUpdated ?? Date(), calendar: .current)
                let divisor = pow(10.0, Double(MoneyFormatting.minorUnitDigits(for: currency)))
                let values = points.map { Double($0.amountMinor) / divisor }
                let minimum = min(values.min() ?? 0, 0)
                let maximum = max(values.max() ?? 0, 0)
                let padding = max((maximum - minimum) * 0.1, 1 / divisor)
                Chart(points, id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value(currency, Double(point.amountMinor) / divisor)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: (minimum - padding)...(maximum + padding))
                .frame(maxHeight: .infinity)
                .accessibilityLabel("Daily \(currency) revenue over the last 30 days")

                HStack {
                    Text(points.first?.day.formatted(.dateTime.month(.abbreviated).day()) ?? "")
                    Spacer()
                    Text(points.last?.day.formatted(.dateTime.month(.abbreviated).day()) ?? "")
                }
                .font(Tokens.Typography.caption())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
            } else {
                chartMessage(service.errors.isEmpty ? "No sales in the last 30 days" : "No sales from available providers")
            }

            if !service.errors.isEmpty, service.errors.count < service.connectedProviders.count {
                Text("Partial · \(service.errors.count) provider\(service.errors.count == 1 ? "" : "s") unavailable")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(AssistDesignTokens.Palette.warning)
                    .lineLimit(1)
                    .help("The chart and totals omit providers that could not be refreshed.")
            }
        }
        .padding(Tokens.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
    }

    private func chartMessage(_ message: String) -> some View {
        Text(message)
            .font(Tokens.Typography.caption())
            .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var totalsSummary: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
            Text("Last 30 days")
                .font(Tokens.Typography.caption(.medium))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))

            Text(amountText(service.summary?.totals[.month]))
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            ForEach([RevenueWindow.today, .week]) { window in
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    Text(window.title)
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                    Spacer(minLength: 0)
                    Text(amountText(service.summary?.totals[window]))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(Tokens.Typography.caption(.medium).monospacedDigit())
                .accessibilityElement(children: .combine)
            }
        }
        .padding(Tokens.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
        .accessibilityElement(children: .contain)
    }

    private var providerDetail: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
            Text("Providers · 30 days")
                .font(Tokens.Typography.caption(.semibold))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
                    ForEach(service.connectedProviders) { provider in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(provider.title)
                                .font(Tokens.Typography.caption(.medium))
                                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                            if let error = service.errors[provider] {
                                Text(error)
                                    .font(Tokens.Typography.caption())
                                    .foregroundStyle(AssistDesignTokens.Palette.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text(amountText(service.summary?.providerTotals[provider]))
                                    .font(Tokens.Typography.footnote(.semibold).monospacedDigit())
                                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        if service.summary == nil { return "Loading…" }
        if service.errors.count == service.connectedProviders.count { return "Unavailable" }
        guard let selectedCurrency else { return "No sales" }
        return MoneyFormatting.format(minor: totals?.amounts[selectedCurrency] ?? 0, currency: selectedCurrency)
    }
}
