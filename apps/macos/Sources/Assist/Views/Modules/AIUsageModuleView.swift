import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The AI Usage module: Claude Code and Codex usage read from their session
/// logs on this Mac.
struct AIUsageModuleView: View {
    @ObservedObject var service: AIUsageService
    @State private var selectedProvider: Provider = .claude

    private enum Provider {
        case claude, codex
    }

    var body: some View {
        let now = service.lastUpdated ?? Date()

        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "AI Usage")
            } trailing: {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    IslandChip(title: "Claude Code", isSelected: selectedProvider == .claude, horizontalPadding: Tokens.Spacing.xSmall) {
                        selectedProvider = .claude
                    }
                    IslandChip(title: "Codex", isSelected: selectedProvider == .codex, horizontalPadding: Tokens.Spacing.xSmall) {
                        selectedProvider = .codex
                    }
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

            Group {
                if selectedProvider == .claude {
                    UsageCard(
                        dailyTokens: service.isHistoryReady ? service.claude?.dailyTokens : nil,
                        now: now,
                        isHistoryReady: service.isHistoryReady,
                        emptyMessage: "No Claude Code logs in ~/.claude on this Mac."
                    )
                } else {
                    UsageCard(
                        dailyTokens: service.isHistoryReady ? service.codex?.dailyTokens : nil,
                        now: now,
                        isHistoryReady: service.isHistoryReady,
                        emptyMessage: "No Codex logs in ~/.codex on this Mac."
                    )
                }
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
        .background {
            ModuleVisibilityObserver(service: service)
                .accessibilityHidden(true)
        }
    }

}

private struct UsageCard: View {
    let dailyTokens: [Date: Int64]?
    let now: Date
    let isHistoryReady: Bool
    let emptyMessage: String

    var body: some View {
        Group {
            if let dailyTokens {
                UsageActivityGrid(dailyTokens: dailyTokens, now: now)
            } else {
                Text(isHistoryReady ? emptyMessage : "Loading activity…")
                    .font(Tokens.Typography.caption(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(Tokens.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
    }
}

private struct UsageActivityGrid: View {
    let dailyTokens: [Date: Int64]
    let now: Date

    private let gap: CGFloat = 2
    private let weekdayLabelWidth: CGFloat = 22
    private let activityColors: [Color] = [
        .white.opacity(Tokens.Opacity.quietSurface),
        .white.opacity(Tokens.Opacity.hoverSurface),
        .white.opacity(Tokens.Opacity.subtle),
        .white.opacity(Tokens.Opacity.secondary),
        .white
    ]

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var weeks: [Date] {
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .weekOfYear, value: 1 - AIUsageScanner.historyWeekCount, to: currentWeek) ?? currentWeek
        return (0..<AIUsageScanner.historyWeekCount).compactMap { week in
            calendar.date(byAdding: .weekOfYear, value: week, to: start)
        }
    }

    var body: some View {
        let maximum = dailyTokens.values.max() ?? 0

        GeometryReader { geometry in
            let capacity = max(1, Int((geometry.size.width - weekdayLabelWidth + gap) / (8 + gap)))
            let visibleWeeks = Array(weeks.suffix(capacity))
            let cell = max(4, min(9, floor((geometry.size.width - weekdayLabelWidth - CGFloat(visibleWeeks.count - 1) * gap) / CGFloat(visibleWeeks.count))))

            VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
                HStack(alignment: .top, spacing: gap) {
                    Color.clear.frame(width: weekdayLabelWidth, height: 12)
                    ForEach(visibleWeeks, id: \.self) { week in
                        Text(monthLabel(for: week))
                            .font(Tokens.Typography.micro(.medium))
                            .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                            .fixedSize()
                            .frame(width: cell, height: 12, alignment: .leading)
                    }
                }

                HStack(alignment: .top, spacing: gap) {
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { row in
                            Text([0: "Mon", 2: "Wed", 4: "Fri"][row] ?? "")
                                .font(Tokens.Typography.micro())
                                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                                .frame(width: weekdayLabelWidth, height: cell, alignment: .leading)
                        }
                    }
                    ForEach(visibleWeeks, id: \.self) { week in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { row in
                                if let day = calendar.date(byAdding: .day, value: row, to: week) {
                                    let tokens = dailyTokens[day] ?? 0
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(day > now ? .clear : color(for: tokens, maximum: maximum))
                                        .frame(width: cell, height: cell)
                                        .help("\(day.formatted(date: .abbreviated, time: .omitted)): \(tokens.formatted()) tokens")
                                        .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(tokens) tokens")
                                        .accessibilityHidden(day > now)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: Tokens.Spacing.xxSmall) {
                    Text("Daily tokens · \(visibleWeeks.count) weeks")
                    Spacer(minLength: 0)
                    Text("Less")
                    ForEach(activityColors.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(activityColors[index])
                            .frame(width: 7, height: 7)
                    }
                    Text("More")
                }
                .font(Tokens.Typography.micro())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
            }
        }
        .accessibilityLabel("Daily token activity by week")
    }

    private func monthLabel(for week: Date) -> String {
        let firstOfMonth = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week) }
            .first { calendar.component(.day, from: $0) == 1 }
        guard let firstOfMonth else { return "" }
        return firstOfMonth.formatted(.dateTime.month(.abbreviated))
    }

    private func color(for tokens: Int64, maximum: Int64) -> Color {
        guard tokens > 0, maximum > 0 else { return activityColors[0] }
        let fraction = Double(tokens) / Double(maximum)
        switch fraction {
        case ..<0.25: return activityColors[1]
        case ..<0.5: return activityColors[2]
        case ..<0.75: return activityColors[3]
        default: return activityColors[4]
        }
    }
}
