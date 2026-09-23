import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// A module's toolbar: controls on the leading side, actions on the trailing side.
struct IslandModuleToolbar<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.small) {
            leading
            Spacer(minLength: Tokens.Spacing.small)
            trailing
        }
        .frame(height: ModuleTokens.toolbarHeight)
        .zIndex(1)
    }
}

extension IslandModuleToolbar where Trailing == EmptyView {
    init(@ViewBuilder leading: () -> Leading) {
        self.init(leading: leading) { EmptyView() }
    }
}

/// A module's heading in its toolbar, with an optional quieter detail.
struct IslandModuleTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.xSmall) {
            Text(title)
                .font(Tokens.Typography.footnote(.semibold))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(Tokens.Typography.footnote(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
            }
        }
        .lineLimit(1)
    }
}

/// A selectable black-and-white chip: selection inverts it to white with black text.
struct IslandChip: View {
    let title: String
    let isSelected: Bool
    var accessibilityLabel: String?
    var horizontalPadding: CGFloat = Tokens.Spacing.medium
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Tokens.Typography.footnote(isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? Mono.selectedForeground
                        : Mono.ink.opacity(Tokens.Opacity.secondary)
                )
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, horizontalPadding)
                .frame(height: Tokens.Control.compactHeight)
                .background(isSelected ? Mono.selectedFill : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .animation(Tokens.Motion.quick, value: isSelected)
    }
}

/// A text button on the island. The prominent style is white with black text;
/// the quiet style is a translucent white capsule.
struct IslandTextButton: View {
    let title: String
    var icon: HugeIconKind?
    var isProminent = false
    var isEnabled = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.xxSmall + 1) {
                if let icon {
                    HugeIcon(icon, size: Tokens.Icon.small, color: foreground)
                }
                Text(title)
                    .font(Tokens.Typography.footnote(.semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
            .padding(.horizontal, Tokens.Spacing.medium)
            .frame(height: Tokens.Control.compactHeight)
            .background(background, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Tokens.Opacity.disabledControl)
        .pointingHandCursor(isEnabled: isEnabled)
        .help(title)
        .onHover { isHovered = $0 }
        .animation(Tokens.Motion.quick, value: isHovered)
    }

    private var foreground: Color {
        isProminent ? Mono.selectedForeground : Mono.ink.opacity(Tokens.Opacity.primary)
    }

    private var background: Color {
        if isProminent {
            return Mono.selectedFill.opacity(isHovered && isEnabled ? Tokens.Opacity.strong : 1)
        }
        return Mono.ink.opacity(
            isHovered && isEnabled ? Tokens.Opacity.hoverSurface : Tokens.Opacity.quietSurface + 0.02
        )
    }
}

/// An icon button that shows an on state with full-white ink and a short bar
/// beneath it, keeping the icon itself free of a background fill.
struct IslandToggleIconButton: View {
    let icon: HugeIconKind
    let tooltip: String
    let isOn: Bool
    var size: CGFloat = ModuleTabLayout.tabWidth
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HugeIcon(
                icon,
                size: ModuleTokens.tabIcon,
                color: Mono.ink.opacity(
                    isOn || isHovered ? Tokens.Opacity.primary : Tokens.Opacity.muted
                )
            )
            .frame(width: size, height: size)
            .background(
                isHovered ? Mono.hoverSurface : .clear,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
            )
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Mono.ink)
                    .frame(width: isOn ? 12 : 0, height: 2)
                    .offset(y: 3)
                    .opacity(isOn ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .accessibilityLabel(tooltip)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .overlay(alignment: .top) {
            if isHovered {
                IslandTooltip(text: tooltip)
                    .offset(y: size + Tokens.Spacing.small)
                    .transition(.opacity)
            }
        }
        .zIndex(isHovered ? 20 : 0)
        .onHover { isHovered = $0 }
        .animation(Tokens.Motion.quick, value: isHovered)
        .animation(Tokens.Motion.quick, value: isOn)
    }
}

/// A thin black-and-white meter. A missing value leaves only the track.
struct IslandMeter: View {
    let fraction: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Mono.track)
                if let fraction {
                    Capsule()
                        .fill(Mono.meter)
                        .frame(width: geometry.size.width * CGFloat(min(max(fraction, 0), 1)))
                }
            }
        }
        .frame(height: ModuleTokens.meterHeight)
        .accessibilityHidden(true)
    }
}

/// A resting surface for a module's tiles.
struct IslandTileBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: ModuleTokens.tileRadius, style: .continuous)
            .fill(Mono.surface)
    }
}

/// Where files can be dropped. The dashed outline brightens while a drag is over the island.
struct IslandDropZone: View {
    let icon: HugeIconKind
    let title: String
    let message: String
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: Tokens.Spacing.xSmall) {
            HugeIcon(
                icon,
                size: Tokens.Icon.feedback,
                color: Mono.ink.opacity(isTargeted ? Tokens.Opacity.primary : Tokens.Opacity.subtle)
            )
            Text(title)
                .font(Tokens.Typography.footnote(.semibold))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
            Text(message)
                .font(Tokens.Typography.caption(.medium))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(Tokens.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: ModuleTokens.tileRadius, style: .continuous)
                .strokeBorder(
                    isTargeted ? Mono.dropTargetOutline : Mono.dropOutline,
                    style: StrokeStyle(
                        lineWidth: ModuleTokens.dropOutlineWidth,
                        dash: ModuleTokens.dropOutlineDash
                    )
                )
        }
        .animation(Tokens.Motion.quick, value: isTargeted)
    }
}

/// A centered message for a module with nothing to show yet.
struct IslandEmptyState<Actions: View>: View {
    let icon: HugeIconKind
    let title: String
    let message: String
    private let actions: Actions

    init(icon: HugeIconKind, title: String, message: String, @ViewBuilder actions: () -> Actions) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.small) {
            HugeIcon(icon, size: 20, color: Mono.ink.opacity(Tokens.Opacity.subtle))
                .padding(.bottom, Tokens.Spacing.xxxSmall)
            Text(title)
                .font(Tokens.Typography.headline)
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
            Text(message)
                .font(Tokens.Typography.footnote(.medium))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .fixedSize(horizontal: false, vertical: true)
            actions
                .padding(.top, Tokens.Spacing.xxSmall)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension IslandEmptyState where Actions == EmptyView {
    init(icon: HugeIconKind, title: String, message: String) {
        self.init(icon: icon, title: title, message: message) { EmptyView() }
    }
}
