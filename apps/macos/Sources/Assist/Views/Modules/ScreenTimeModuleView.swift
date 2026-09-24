import AppKit
import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Screen Time module: where today went, app by app.
struct ScreenTimeModuleView: View {
    @ObservedObject var tracker: ScreenTimeTracker

    private static let visibleAppCount = 4

    var body: some View {
        let entries = Array(tracker.entries().prefix(Self.visibleAppCount))
        let longest = entries.first?.duration ?? 0

        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Screen Time")
            }

            Group {
                if entries.isEmpty {
                    IslandEmptyState(
                        icon: .hourglass,
                        title: "Tracking today",
                        message: "Time in each app appears here as you work. It never leaves this Mac."
                    )
                } else {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.small) {
                            Text("Today")
                                .font(Tokens.Typography.caption(.medium))
                                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                            Text(TimerFormatting.minutes(tracker.total()))
                                .font(Tokens.Typography.title.monospacedDigit())
                                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                                .accessibilityLabel("Today, \(TimerFormatting.minutes(tracker.total()))")
                        }
                        .frame(height: 26)

                        ScreenTimeTopApp(
                            entry: entries[0],
                            icon: tracker.icon(for: entries[0].bundleIdentifier)
                        )

                        ForEach(1..<entries.count, id: \.self) { index in
                            let entry = entries[index]
                            ScreenTimeRankedRow(
                                rank: index + 1,
                                entry: entry,
                                icon: tracker.icon(for: entry.bundleIdentifier),
                                fraction: longest > 0 ? entry.duration / longest : 0
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
        .onAppear {
            tracker.flush()
        }
    }
}

private struct ScreenTimeTopApp: View {
    let entry: ScreenTimeEntry
    let icon: NSImage?

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            Text("01")
                .font(Tokens.Typography.caption(.medium).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .frame(width: 18, alignment: .leading)
            ScreenTimeAppIcon(icon: icon, size: 20)
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxSmall) {
                Text(entry.name)
                    .font(Tokens.Typography.footnote(.semibold))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                    .lineLimit(1)
                Text("Most used")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            IslandMeter(fraction: 1)
                .frame(width: 72)
            Text(TimerFormatting.minutes(entry.duration))
                .font(Tokens.Typography.footnote(.semibold).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                .frame(minWidth: 66, alignment: .trailing)
        }
        .padding(.horizontal, Tokens.Spacing.medium)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(IslandTileBackground())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Top app, \(entry.name), \(TimerFormatting.minutes(entry.duration))")
    }
}

private struct ScreenTimeRankedRow: View {
    let rank: Int
    let entry: ScreenTimeEntry
    let icon: NSImage?
    let fraction: Double

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            Text(String(format: "%02d", rank))
                .font(Tokens.Typography.caption(.medium).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .frame(width: 18, alignment: .leading)
            ScreenTimeAppIcon(icon: icon, size: Tokens.Icon.regular)
                .frame(width: 20)
            Text(entry.name)
                .font(Tokens.Typography.footnote(.medium))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            IslandMeter(fraction: fraction)
                .frame(width: 72)
            Text(TimerFormatting.minutes(entry.duration))
                .font(Tokens.Typography.caption(.medium).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                .frame(minWidth: 66, alignment: .trailing)
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank), \(entry.name), \(TimerFormatting.minutes(entry.duration))")
    }
}

private struct ScreenTimeAppIcon: View {
    let icon: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .grayscale(1)
            } else {
                HugeIcon(.desktop, size: size, color: Mono.ink.opacity(Tokens.Opacity.muted))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
