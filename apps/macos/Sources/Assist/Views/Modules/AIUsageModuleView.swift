import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The AI Usage module: Claude Code and Codex usage read from their session
/// logs on this Mac.
struct AIUsageModuleView: View {
    @ObservedObject var service: AIUsageService

    var body: some View {
        let now = service.lastUpdated ?? Date()

        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "AI Usage", detail: "From local logs")
            } trailing: {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    if service.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Refreshing")
                    }
                    IslandIconButton(
                        icon: .refresh,
                        tooltip: "Refresh usage",
                        isEnabled: !service.isRefreshing,
                        size: Tokens.Control.compactHeight
                    ) {
                        service.refresh()
                    }
                }
            }

            HStack(spacing: Tokens.Spacing.small) {
                UsageCard(title: "Claude Code", subtitle: service.claude?.model) {
                    if service.lastUpdated == nil {
                        UsageCardMessage(text: "Reading logs…")
                    } else if let claude = service.claude {
                        claudeRows(claude, now: now)
                    } else {
                        UsageCardMessage(text: "No Claude Code logs in ~/.claude on this Mac.")
                    }
                }

                UsageCard(title: "Codex", subtitle: service.codex?.model) {
                    if service.lastUpdated == nil {
                        UsageCardMessage(text: "Reading logs…")
                    } else if let codex = service.codex {
                        codexRows(codex)
                    } else {
                        UsageCardMessage(text: "No Codex logs in ~/.codex on this Mac.")
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

    @ViewBuilder
    private func claudeRows(_ claude: ClaudeUsageSummary, now: Date) -> some View {
        if let resetAt = claude.limitResetAt {
            UsageRow(
                label: "Limit reached",
                value: "resets \(resetAt.formatted(date: .omitted, time: .shortened))",
                fraction: 1
            )
        } else if let block = claude.activeBlock {
            UsageRow(
                label: "5-hour window",
                value: "\(TokenFormatting.compact(block.tokens.total)) · resets \(block.end.formatted(date: .omitted, time: .shortened))",
                fraction: block.elapsedFraction(at: now)
            )
        } else {
            UsageRow(label: "5-hour window", value: "Not started", fraction: 0)
        }

        UsageRow(
            label: "Today",
            value: "\(TokenFormatting.compact(claude.today.total)) · \(claude.todayRequests) requests",
            fraction: nil
        )

        if let context = claude.contextTokens {
            UsageRow(
                label: "Context",
                value: "\(TokenFormatting.compact(context)) of \(TokenFormatting.compact(claude.contextWindow))",
                fraction: Double(context) / Double(claude.contextWindow)
            )
        }
    }

    @ViewBuilder
    private func codexRows(_ codex: CodexUsageSummary) -> some View {
        if let primary = codex.primary {
            limitRow(primary)
        }
        if let secondary = codex.secondary {
            limitRow(secondary)
        }
        if codex.primary == nil, codex.secondary == nil {
            UsageRow(label: "Limits", value: "Not reported yet", fraction: nil)
        }

        UsageRow(label: "Today", value: TokenFormatting.compact(codex.todayTokens), fraction: nil)

        if let context = codex.contextTokens, let window = codex.contextWindow, window > 0 {
            UsageRow(
                label: "Context",
                value: "\(TokenFormatting.compact(context)) of \(TokenFormatting.compact(window))",
                fraction: Double(context) / Double(window)
            )
        }
    }

    private func limitRow(_ window: CodexRateLimitWindow) -> some View {
        let used = "\(Int(window.usedPercent.rounded()))% used"
        let reset = window.resetsAt.map { " · resets \(resetText($0))" } ?? ""
        return UsageRow(label: window.title, value: used + reset, fraction: window.usedPercent / 100)
    }

    /// A time today, or a weekday and time for later resets.
    private func resetText(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

private struct UsageCard<Content: View>: View {
    let title: String
    let subtitle: String?
    private let content: Content

    init(title: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xSmall) {
                Text(title)
                    .font(Tokens.Typography.footnote(.semibold))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            content

            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
    }
}

private struct UsageRow: View {
    let label: String
    let value: String
    /// Draws a meter when set.
    let fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxxSmall + 1) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xSmall) {
                Text(label)
                    .font(Tokens.Typography.caption(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                    .lineLimit(1)
                Spacer(minLength: Tokens.Spacing.xxSmall)
                Text(value)
                    .font(Tokens.Typography.caption(.semibold).monospacedDigit())
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            if let fraction {
                IslandMeter(fraction: fraction)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UsageCardMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Tokens.Typography.caption(.medium))
            .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
            .fixedSize(horizontal: false, vertical: true)
    }
}
