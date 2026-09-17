import SwiftUI

struct LibrarySidebar: View {
    @Binding var selectedFilter: ClipboardHistoryFilter
    let counts: [ClipboardHistoryFilter: Int]
    let openSettings: () -> Void
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                AssistLogo(size: 26)
                Text("Assist")
                    .font(Tokens.Typography.title)
            }
            .padding(.horizontal, Tokens.AppLayout.sidebarInset)
            .padding(.top, Tokens.AppLayout.sidebarTopInset)
            .padding(.bottom, 28)
            .accessibilityElement(children: .combine)

            Text("Library")
                .font(Tokens.Typography.section)
                .foregroundStyle(theme.muted)
                .padding(.horizontal, Tokens.AppLayout.sidebarInset)
                .padding(.bottom, Tokens.Spacing.small)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: Tokens.Spacing.xxSmall) {
                ForEach(ClipboardHistoryFilter.allCases) { filter in
                    AssistNavigationRow(
                        title: filter.navigationTitle,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        count: counts[filter, default: 0]
                    ) {
                        selectedFilter = filter
                    }
                }
            }

            Spacer()

            privacyNote
                .padding(.bottom, 16)

            AssistNavigationRow(title: "Settings", icon: .settings, action: openSettings)
        }
        .padding(.horizontal, Tokens.AppLayout.sidebarInset)
        .padding(.bottom, Tokens.AppLayout.sidebarInset)
        .frame(width: Tokens.AppLayout.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
            Text("Right here on your Mac")
                .font(Tokens.Typography.small(.medium))
                .foregroundStyle(theme.foreground)
            Text("Your captures and clipboard history stay local.")
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(Tokens.Spacing.xLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentSurface, in: RoundedRectangle(cornerRadius: Tokens.Radius.large))
        .accessibilityElement(children: .combine)
    }

}

struct LibraryWelcomeHeader: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 9) {
                Text("Hold")
                AssistKeycapRow(keys: CaptureShortcut.annotate.keyNames)
                Text("to draw on your screen")
            }
            .font(Tokens.Typography.display)
            .foregroundStyle(theme.foreground)
            .accessibilityElement(children: .combine)

            HStack(spacing: 0) {
                ForEach(Array(CaptureShortcut.all.enumerated()), id: \.element.id) { index, shortcut in
                    if index > 0 {
                        Rectangle()
                            .fill(theme.border)
                            .frame(width: Tokens.Control.borderWidth, height: 44)
                    }
                    card(for: shortcut)
                }
            }
            .padding(.vertical, 16)
            .background(theme.control, in: RoundedRectangle(cornerRadius: Tokens.Radius.large))
        }
    }

    private func card(for shortcut: CaptureShortcut) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            HStack(spacing: Tokens.Spacing.xSmall) {
                HugeIcon(shortcut.icon, size: Tokens.Icon.feedback, color: theme.muted)
                Spacer(minLength: Tokens.Spacing.xxSmall)
                AssistKeycapRow(keys: shortcut.keyNames)
            }
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                Text(shortcut.title).font(Tokens.Typography.body())
                Text(shortcut.detail).font(Tokens.Typography.caption()).foregroundStyle(theme.muted)
            }
        }
        .padding(.horizontal, Tokens.Spacing.xxLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
