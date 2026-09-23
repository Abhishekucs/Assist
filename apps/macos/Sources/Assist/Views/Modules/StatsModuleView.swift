import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The System module: CPU, memory, disk, network, and battery. It samples only
/// while it is on screen.
struct StatsModuleView: View {
    @ObservedObject var service: SystemStatsService

    var body: some View {
        let snapshot = service.snapshot

        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "System", detail: "Live")
            }

            HStack(spacing: Tokens.Spacing.small) {
                StatTile(
                    icon: .cpu,
                    label: "CPU",
                    value: snapshot.cpuUsage.map(StatsFormatting.percent) ?? "—",
                    detail: "\(ProcessInfo.processInfo.activeProcessorCount) cores",
                    fraction: snapshot.cpuUsage
                )

                StatTile(
                    icon: .memory,
                    label: "Memory",
                    value: snapshot.memoryUsed.map { StatsFormatting.bytes(Int64($0)) } ?? "—",
                    detail: "of \(StatsFormatting.bytes(Int64(snapshot.memoryTotal)))",
                    fraction: snapshot.memoryFraction
                )

                StatTile(
                    icon: .disk,
                    label: "Disk",
                    value: snapshot.disk.map { StatsFormatting.fileBytes($0.available) } ?? "—",
                    detail: snapshot.disk.map { "free of \(StatsFormatting.fileBytes($0.total))" } ?? "Startup disk",
                    fraction: snapshot.disk?.usedFraction
                )

                StatTile(
                    icon: .network,
                    label: "Network",
                    value: snapshot.network.map { "↓ \(StatsFormatting.rate($0.receivedPerSecond))" } ?? "—",
                    detail: snapshot.network.map { "↑ \(StatsFormatting.rate($0.sentPerSecond))" } ?? "Measuring…",
                    fraction: nil
                )

                batteryTile(snapshot.battery)
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

    private func batteryTile(_ battery: BatteryStatus?) -> some View {
        guard let battery else {
            return StatTile(icon: .battery, label: "Battery", value: "—", detail: "No battery", fraction: nil)
        }

        var details: [String] = []
        if battery.isCharging {
            details.append("Charging")
        } else if battery.isOnPowerAdapter {
            details.append("Plugged in")
        } else {
            details.append("On battery")
        }
        if let health = battery.health {
            details.append("Health \(StatsFormatting.percent(health))")
        }
        if let cycleCount = battery.cycleCount {
            details.append("\(cycleCount) cycles")
        }

        return StatTile(
            icon: battery.isCharging ? .batteryCharging : .battery,
            label: "Battery",
            value: StatsFormatting.percent(battery.level),
            detail: details.joined(separator: "\n"),
            fraction: battery.level
        )
    }
}

private struct StatTile: View {
    let icon: HugeIconKind
    let label: String
    let value: String
    let detail: String
    let fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
            HStack(spacing: Tokens.Spacing.xxSmall) {
                HugeIcon(icon, size: Tokens.Icon.small, color: Mono.ink.opacity(Tokens.Opacity.secondary))
                Text(label)
                    .font(Tokens.Typography.caption(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
            }

            Text(value)
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, Tokens.Spacing.xxSmall)

            Text(detail)
                .font(Tokens.Typography.caption())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            IslandMeter(fraction: fraction)
                .opacity(fraction == nil ? 0 : 1)
        }
        .padding(Tokens.Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value). \(detail)")
    }
}
