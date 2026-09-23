import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Timers module: Pomodoro focus sessions, a countdown, a stopwatch, and
/// the hydration reminder. A running timer also shows on the collapsed island.
struct TimersModuleView: View {
    @ObservedObject var timers: FocusTimerService

    private static let hydrationCardWidth: CGFloat = 176

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    ForEach(TimerMode.allCases) { mode in
                        IslandChip(title: mode.title, isSelected: timers.mode == mode) {
                            timers.select(mode)
                        }
                    }
                }
            } trailing: {
                if timers.mode == .countdown {
                    HStack(spacing: Tokens.Spacing.xxxSmall) {
                        ForEach(FocusTimerService.countdownPresets, id: \.self) { preset in
                            IslandChip(
                                title: presetTitle(preset),
                                isSelected: timers.countdownDuration == preset,
                                accessibilityLabel: "\(TimerFormatting.minutes(preset)) timer",
                                horizontalPadding: Tokens.Spacing.small
                            ) {
                                timers.setCountdown(preset)
                            }
                        }
                    }
                    .disabled(timers.clock.hasStarted)
                    .opacity(timers.clock.hasStarted ? Tokens.Opacity.disabledControl : 1)
                }
            }

            HStack(spacing: Tokens.Spacing.large) {
                timerCard
                hydrationCard
                    .frame(width: Self.hydrationCardWidth)
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
    }

    private var timerCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(timers.displayTime)
                    .font(.system(size: 38, weight: .light).monospacedDigit())
                    .foregroundStyle(Mono.ink.opacity(timers.isRunning ? Tokens.Opacity.primary : Tokens.Opacity.strong))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("\(timers.mode.title), \(timers.displayTime)")

                Spacer(minLength: Tokens.Spacing.small)

                Text(timers.statusTitle)
                    .font(Tokens.Typography.caption(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                    .lineLimit(1)
            }

            IslandMeter(fraction: timers.progress)
                .opacity(timers.mode == .stopwatch ? 0 : 1)

            Spacer(minLength: 0)

            HStack(spacing: Tokens.Spacing.xSmall) {
                IslandTextButton(
                    title: timers.isRunning ? "Pause" : (timers.clock.hasStarted ? "Resume" : "Start"),
                    icon: timers.isRunning ? .pause : .play,
                    isProminent: true
                ) {
                    timers.toggleRunning()
                }

                IslandTextButton(title: "Reset", icon: .refresh, isEnabled: canReset) {
                    timers.reset()
                }

                if timers.mode == .pomodoro {
                    IslandTextButton(title: "Skip", icon: .next) {
                        timers.skipPhase()
                    }
                    .help("End this \(timers.phase.title.lowercased()) and start the next phase")
                }

                Spacer(minLength: 0)

                if timers.mode == .countdown {
                    IslandIconButton(
                        icon: .minus,
                        tooltip: "One minute less",
                        isEnabled: !timers.clock.hasStarted
                            && timers.countdownDuration > FocusTimerService.countdownRange.lowerBound,
                        size: Tokens.Control.compactHeight
                    ) {
                        timers.adjustCountdown(byMinutes: -1)
                    }
                    IslandIconButton(
                        icon: .add,
                        tooltip: "One minute more",
                        isEnabled: !timers.clock.hasStarted
                            && timers.countdownDuration < FocusTimerService.countdownRange.upperBound,
                        size: Tokens.Control.compactHeight
                    ) {
                        timers.adjustCountdown(byMinutes: 1)
                    }
                }
            }
        }
        .padding(Tokens.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
    }

    private var hydrationCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
            HStack(spacing: Tokens.Spacing.xSmall) {
                HugeIcon(.droplet, size: Tokens.Icon.regular, color: Mono.ink.opacity(Tokens.Opacity.primary))
                Text("Hydration")
                    .font(Tokens.Typography.footnote(.semibold))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
            }

            Text(hydrationStatus)
                .font(Tokens.Typography.caption(.medium))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("Remind me every (minutes)")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))

            HStack(spacing: 0) {
                IslandChip(
                    title: "Off",
                    isSelected: !timers.isHydrationEnabled,
                    accessibilityLabel: "Hydration reminders off",
                    horizontalPadding: Tokens.Spacing.xSmall
                ) {
                    timers.setHydrationEnabled(false)
                }
                ForEach(FocusTimerService.hydrationIntervals, id: \.self) { interval in
                    IslandChip(
                        title: "\(Int(interval / 60))",
                        isSelected: timers.isHydrationEnabled && timers.hydrationInterval == interval,
                        accessibilityLabel: "Every \(TimerFormatting.minutes(interval))",
                        horizontalPadding: Tokens.Spacing.xSmall
                    ) {
                        timers.setHydrationInterval(interval)
                        timers.setHydrationEnabled(true)
                    }
                }
            }
        }
        .padding(Tokens.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IslandTileBackground())
    }

    private var canReset: Bool {
        timers.clock.hasStarted || (timers.mode == .pomodoro && timers.completedFocusSessions > 0)
    }

    private var hydrationStatus: String {
        guard timers.isHydrationEnabled, let next = timers.nextHydrationAt else {
            return "Off. Pick an interval to get a gentle nudge."
        }
        return "Next reminder at \(next.formatted(date: .omitted, time: .shortened))"
    }

    private func presetTitle(_ preset: TimeInterval) -> String {
        let minutes = Int(preset / 60)
        return minutes >= 60 && minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes)m"
    }
}
