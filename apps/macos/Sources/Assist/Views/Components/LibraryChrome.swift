import SwiftUI

struct LibrarySidebar: View {
    @Binding var selectedModule: AssistModule?
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

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xLarge) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                        VStack(spacing: Tokens.Spacing.xxSmall) {
                            AssistNavigationRow(
                                title: "Library",
                                icon: .grid,
                                isSelected: selectedModule == nil
                            ) {
                                selectedModule = nil
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
                        sectionHeader("Modules")
                        VStack(spacing: Tokens.Spacing.xxSmall) {
                            ForEach(AssistModule.allCases.filter { $0 != .clipboard }) { module in
                                AssistNavigationRow(
                                    title: module.title,
                                    icon: module.icon,
                                    isSelected: selectedModule == module
                                ) {
                                    selectedModule = module
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, Tokens.Spacing.medium)
            }

            AssistNavigationRow(title: "Settings", icon: .settings, action: openSettings)
        }
        .padding(.horizontal, Tokens.AppLayout.sidebarInset)
        .padding(.bottom, Tokens.AppLayout.sidebarInset)
        .frame(width: Tokens.AppLayout.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Tokens.Typography.section)
            .foregroundStyle(theme.muted)
            .padding(.horizontal, Tokens.AppLayout.sidebarInset)
            .accessibilityAddTraits(.isHeader)
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
