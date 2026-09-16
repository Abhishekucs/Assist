import SwiftUI

struct LibrarySidebar: View {
    @Binding var selectedFilter: ClipboardHistoryFilter
    let items: [ClipboardHistoryItem]
    let openSettings: () -> Void
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                AssistLogo(size: 26)
                Text("Assist")
                    .font(AssistFont.title())
            }
            .padding(.horizontal, 12)
            .padding(.top, 42)
            .padding(.bottom, 28)

            Text("Library")
                .font(AssistFont.caption())
                .foregroundStyle(theme.muted)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(ClipboardHistoryFilter.allCases) { filter in
                    AssistNavigationRow(
                        title: filter == .all ? "All history" : filter.title,
                        icon: icon(for: filter),
                        isSelected: selectedFilter == filter,
                        count: items.filter(filter.includes).count
                    ) {
                        selectedFilter = filter
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Right here on your Mac")
                    .font(AssistFont.small(.medium))
                    .foregroundStyle(theme.foreground)
                Text("Your captures and clipboard history stay local.")
                    .font(AssistFont.caption())
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accentSurface, in: RoundedRectangle(cornerRadius: 14))
            .padding(.bottom, 16)

            AssistNavigationRow(title: "Settings", icon: .settings, action: openSettings)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 12)
    }

    private func icon(for filter: ClipboardHistoryFilter) -> HugeIconKind {
        switch filter {
        case .all: .grid
        case .text: .document
        case .images: .image
        }
    }
}

struct LibraryWelcomeHeader: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 9) {
                Text("Hold")
                AssistKeycap(title: "Option")
                Text("to capture a thought")
            }
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(theme.foreground)

            HStack(spacing: 0) {
                shortcut(icon: .pen, title: "Annotate a screenshot", detail: "Hold Option and draw on your screen.", keys: ["⌥"])
                Rectangle().fill(theme.border).frame(width: 1, height: 44)
                shortcut(icon: .camera, title: "Take a clean screenshot", detail: "Capture your screen, ready to edit.", keys: ["⌃", "⌥"])
            }
            .padding(.vertical, 16)
            .background(theme.control, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func shortcut(icon: HugeIconKind, title: String, detail: String, keys: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                HugeIcon(icon, size: 18, color: theme.muted)
                Spacer(minLength: 4)
                ForEach(keys, id: \.self) { AssistKeycap(title: $0) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AssistFont.body())
                Text(detail).font(AssistFont.caption()).foregroundStyle(theme.muted)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
