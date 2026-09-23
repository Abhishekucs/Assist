import AppKit
import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Screen Time module: where today went, app by app.
struct ScreenTimeModuleView: View {
    @ObservedObject var tracker: ScreenTimeTracker

    private static let visibleAppCount = 6

    var body: some View {
        let entries = Array(tracker.entries().prefix(Self.visibleAppCount))
        let longest = entries.first?.duration ?? 0

        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Screen Time", detail: "Today · \(TimerFormatting.minutes(tracker.total()))")
            }

            Group {
                if entries.isEmpty {
                    IslandEmptyState(
                        icon: .hourglass,
                        title: "Tracking today",
                        message: "Time in each app appears here as you work. It never leaves this Mac."
                    )
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: Tokens.Spacing.large),
                            GridItem(.flexible(), spacing: Tokens.Spacing.large)
                        ],
                        alignment: .leading,
                        spacing: Tokens.Spacing.small
                    ) {
                        ForEach(entries) { entry in
                            ScreenTimeRow(
                                entry: entry,
                                icon: tracker.icon(for: entry.bundleIdentifier),
                                fraction: longest > 0 ? entry.duration / longest : 0
                            )
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
        .onAppear {
            tracker.flush()
        }
    }
}

private struct ScreenTimeRow: View {
    let entry: ScreenTimeEntry
    let icon: NSImage?
    let fraction: Double

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .grayscale(1)
                } else {
                    HugeIcon(.desktop, size: Tokens.Icon.regular, color: Mono.ink.opacity(Tokens.Opacity.muted))
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.name)
                        .font(Tokens.Typography.footnote(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                        .lineLimit(1)
                    Spacer(minLength: Tokens.Spacing.xSmall)
                    Text(TimerFormatting.minutes(entry.duration))
                        .font(Tokens.Typography.caption(.medium).monospacedDigit())
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                }
                IslandMeter(fraction: fraction)
            }
        }
        .frame(height: 38)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.name), \(TimerFormatting.minutes(entry.duration))")
    }
}
