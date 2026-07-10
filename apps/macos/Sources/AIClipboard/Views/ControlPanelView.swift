import AppKit
import Combine
import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var settings: PillSettings
    @ObservedObject var viewModel: PillViewModel
    @State private var selectedPage: SettingsPage = .updates
    @State private var isSettingsDialogPresented = false
    @State private var resolvedSystemColorScheme = SystemAppearanceResolver.currentColorScheme()

    private var activeScheme: ColorScheme {
        switch settings.appAppearance {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            resolvedSystemColorScheme
        }
    }

    var body: some View {
        let theme = AssistTheme(colorScheme: activeScheme)

        ZStack {
            VStack(spacing: 0) {
                AppTopBar(isSettingsDialogPresented: $isSettingsDialogPresented)
                    .frame(height: 58)

                Rectangle()
                    .fill(theme.border)
                    .frame(height: 1)

                CaptureLibraryView(viewModel: viewModel)
            }

            if isSettingsDialogPresented {
                Color.black
                    .opacity(theme.isDark ? 0.34 : 0.16)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        isSettingsDialogPresented = false
                    }

                SettingsDialog {
                    isSettingsDialogPresented = false
                } content: {
                    settingsView(theme: theme)
                }
                .frame(width: 720, height: 452)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.985, anchor: .center).combined(with: .opacity)
                    )
                )
            }
        }
        .frame(width: 980, height: 700)
        .background(theme.background)
        .foregroundStyle(theme.foreground)
        .font(.body)
        .environment(\.assistTheme, theme)
        .preferredColorScheme(settings.appAppearance.preferredColorScheme)
        .animation(.spring(response: 0.24, dampingFraction: 0.92), value: isSettingsDialogPresented)
        .onAppear {
            viewModel.willShowHistory()
            refreshSystemColorScheme()
        }
        .onChange(of: settings.appAppearance) { _, appearance in
            guard appearance == .system else { return }
            refreshSystemColorScheme()
            DispatchQueue.main.async {
                refreshSystemColorScheme()
            }
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: SystemAppearanceResolver.changeNotification)) { _ in
            refreshSystemColorScheme()
        }
    }

    private func refreshSystemColorScheme() {
        resolvedSystemColorScheme = SystemAppearanceResolver.currentColorScheme()
    }

    private func settingsView(theme: AssistTheme) -> some View {
        HStack(alignment: .top, spacing: 22) {
            SettingsSidebar(selectedPage: $selectedPage)
                .frame(width: 188)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(10)
        .background(theme.card)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .appearance:
            AppearanceSettingsPane(settings: settings)
        case .capture:
            CaptureSettingsPane(viewModel: viewModel)
        case .storage:
            StorageSettingsPane()
        case .updates:
            UpdatesSettingsPane(settings: settings)
        case .about:
            AboutSettingsPane()
        }
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case appearance
    case capture
    case storage
    case updates
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance:
            "Appearance"
        case .capture:
            "Capture"
        case .storage:
            "Storage"
        case .updates:
            "Updates"
        case .about:
            "About"
        }
    }

    var icon: HugeIconKind {
        switch self {
        case .appearance:
            .appearance
        case .capture:
            .camera
        case .storage:
            .storage
        case .updates:
            .refresh
        case .about:
            .info
        }
    }
}

private extension AppAppearance {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            nil
        }
    }

    var title: String {
        switch self {
        case .light:
            "Light"
        case .dark:
            "Dark"
        case .system:
            "System"
        }
    }

    var description: String {
        switch self {
        case .light:
            "Bright panels"
        case .dark:
            "Dim panels"
        case .system:
            "Follow macOS"
        }
    }

    var icon: HugeIconKind {
        switch self {
        case .light:
            .sun
        case .dark:
            .moon
        case .system:
            .desktop
        }
    }
}

private struct AppTopBar: View {
    @Binding var isSettingsDialogPresented: Bool
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text("Assist")
                .font(AssistFont.title())
                .foregroundStyle(theme.foreground)

            Spacer()

            HugeIconButton(
                kind: .settings,
                tooltip: "Open settings",
                isSelected: isSettingsDialogPresented
            ) {
                isSettingsDialogPresented = true
            }
        }
        .padding(.leading, 26)
        .padding(.trailing, 20)
    }
}

private struct CaptureLibraryView: View {
    @ObservedObject var viewModel: PillViewModel
    @Environment(\.assistTheme) private var theme
    @State private var selectedFilter: LibraryFilter = .all

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 210, maximum: 240), spacing: 14, alignment: .top)]
    }

    private var filteredItems: [ClipboardHistoryItem] {
        viewModel.historyItems.filter { item in
            switch (selectedFilter, item) {
            case (.all, _), (.images, .screenshot), (.text, .text):
                true
            default:
                false
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.historyItems.isEmpty {
                EmptyCaptureLibraryView()
            } else {
                VStack(spacing: 0) {
                    LibraryFilterBar(
                        selectedFilter: $selectedFilter,
                        shownCount: filteredItems.count,
                        totalCount: viewModel.historyItems.count
                    )

                    Rectangle()
                        .fill(theme.border.opacity(0.72))
                        .frame(height: 1)

                    if filteredItems.isEmpty {
                        EmptyFilteredLibraryView(filter: selectedFilter)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                                ForEach(filteredItems) { item in
                                    CaptureLibraryCard(
                                        item: item,
                                        isSelected: item.id == viewModel.selectedItem?.id,
                                        thumbnail: thumbnail(for: item),
                                        selectAction: { select(item) },
                                        deleteAction: { viewModel.delete(item) }
                                    )
                                }
                            }
                            .padding(18)
                        }
                        .background(theme.background)
                    }
                }
                .background(theme.background)
            }
        }
    }

    private func thumbnail(for item: ClipboardHistoryItem) -> NSImage? {
        guard case let .screenshot(capture) = item else { return nil }
        return viewModel.thumbnail(for: capture)
    }

    private func select(_ item: ClipboardHistoryItem) {
        switch item {
        case let .screenshot(capture):
            viewModel.selectScreenshot(capture)
        case let .text(textClip):
            viewModel.copyTextItem(textClip)
        }
    }
}

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case images

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .text:
            "Text"
        case .images:
            "Images"
        }
    }
}

private struct LibraryFilterBar: View {
    @Binding var selectedFilter: LibraryFilter
    let shownCount: Int
    let totalCount: Int
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(spacing: 20) {
            HStack(spacing: 24) {
                ForEach(LibraryFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        VStack(spacing: 7) {
                            Text(filter.title)
                                .font(AssistFont.roundedFootnote(filter == selectedFilter ? .semibold : .medium))
                                .foregroundStyle(filter == selectedFilter ? theme.foreground : theme.muted)
                                .lineLimit(1)

                            Capsule()
                                .fill(filter == selectedFilter ? theme.foreground : .clear)
                                .frame(width: 28, height: 2)
                        }
                        .frame(minWidth: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Show \(filter.title.lowercased())")
                }
            }

            Spacer()

            Text("\(shownCount) of \(totalCount)")
                .font(AssistFont.roundedFootnote(.medium))
                .foregroundStyle(theme.subtle)

            Text("Most recent")
                .font(AssistFont.roundedFootnote(.medium))
                .foregroundStyle(theme.foreground.opacity(0.82))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(theme.selected.opacity(theme.isDark ? 0.72 : 1), in: Capsule())
        }
        .padding(.horizontal, 26)
        .padding(.top, 11)
        .padding(.bottom, 8)
        .background(theme.card)
    }
}

private struct EmptyFilteredLibraryView: View {
    let filter: LibraryFilter
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Text("No \(filter.title.lowercased()) yet")
                .font(.headline)
                .foregroundStyle(theme.foreground)

            Text("Switch to All to see every saved item.")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}

private struct EmptyCaptureLibraryView: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            HugeIcon(.image, size: 32)
                .foregroundStyle(theme.muted)

            Text("No captures yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.foreground)

            Text("Hold Option to annotate a screenshot, or press Control + Option for a clean capture.")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}

private struct CaptureLibraryCard: View {
    private static let cardHeight: CGFloat = 122

    let item: ClipboardHistoryItem
    let isSelected: Bool
    let thumbnail: NSImage?
    let selectAction: () -> Void
    let deleteAction: () -> Void
    @Environment(\.assistTheme) private var theme
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    private var isDeleteVisible: Bool {
        isHovered || isDeleteHovered
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: selectAction) {
                preview
                    .frame(maxWidth: .infinity, minHeight: Self.cardHeight, maxHeight: Self.cardHeight, alignment: .topLeading)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isSelected ? theme.foreground.opacity(0.42) : .clear, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: .black.opacity(theme.isDark ? 0.16 : 0.08), radius: 9, y: 5)
            }
            .buttonStyle(.plain)
            .onDrag { item.dragProvider }
            .help(helpText)

            DeleteIconButton(isHovered: $isDeleteHovered, action: deleteAction)
                .opacity(isDeleteVisible ? 1 : 0.001)
                .zIndex(1)
                .padding(7)
        }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    @ViewBuilder
    private var preview: some View {
        switch item {
        case .screenshot:
            ZStack {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    HugeIcon(.image, size: 30)
                        .foregroundStyle(theme.muted)
                }
            }
        case let .text(textClip):
            VStack(alignment: .leading, spacing: 12) {
                HugeIcon(.document, size: 18)
                    .foregroundStyle(theme.muted)
                Text(textClip.preview)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var cardBackground: Color {
        if isSelected { return theme.selected }
        if isHovered { return theme.card.opacity(theme.isDark ? 0.9 : 1) }
        return theme.card
    }

    private var helpText: String {
        switch item {
        case .screenshot:
            "Select screenshot"
        case .text:
            "Copy text"
        }
    }
}

private struct DeleteIconButton: View {
    @Binding var isHovered: Bool
    let action: () -> Void
    @Environment(\.assistTheme) private var theme

    private var red: Color {
        Color(hex: 0xFF453A)
    }

    var body: some View {
        Button(action: action) {
            HugeIcon(.trash, size: 15, color: red.opacity(isHovered ? 1 : 0.9))
                .frame(width: 34, height: 34)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Delete item")
        .accessibilityLabel("Delete item")
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var backgroundColor: Color {
        red.opacity(isHovered ? (theme.isDark ? 0.24 : 0.16) : (theme.isDark ? 0.16 : 0.1))
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedPage: SettingsPage
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.subtle)
                .padding(.horizontal, 13)
                .padding(.top, 12)
                .padding(.bottom, 10)

            VStack(spacing: 2) {
                ForEach(SettingsPage.allCases) { page in
                    SidebarButton(page: page, isSelected: page == selectedPage) {
                        selectedPage = page
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.bottom, 10)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.border.opacity(theme.isDark ? 0.82 : 1), lineWidth: 1)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SidebarButton: View {
    let page: SettingsPage
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.assistTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                HugeIcon(page.icon, size: 12, color: isSelected ? theme.foreground : theme.muted)
                    .frame(width: 14)
                Text(page.title)
                    .font(.caption.weight(isSelected ? .semibold : .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? theme.foreground : theme.muted)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(page.title)
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var rowBackground: Color {
        if isSelected { return theme.selected }
        if isHovered { return theme.selected.opacity(theme.isDark ? 0.54 : 0.74) }
        return Color.clear
    }
}

private struct SettingsDetailPage<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    @Environment(\.assistTheme) private var theme

    init(title: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.foreground)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 28)

                content
            }
            .padding(.trailing, 18)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(theme.card)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.assistTheme) private var theme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.muted)

            VStack(spacing: 0) {
                content
            }
        }
    }
}

private struct RowDivider: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.border)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}

private struct SettingValueRow: View {
    let title: String
    let value: String
    let detail: String?
    @Environment(\.assistTheme) private var theme

    init(title: String, value: String, detail: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.foreground)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 18)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: detail == nil ? 42 : 56)
    }
}

private struct SettingsActionButton: View {
    let title: String
    let icon: HugeIconKind
    let action: () -> Void
    @Environment(\.assistTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                HugeIcon(icon, size: 12, color: actionForeground)
                Text(title)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(actionForeground)
            .padding(.horizontal, 13)
            .frame(height: 28)
            .background(actionBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
        .pointingHandCursor()
    }

    private var actionBackground: Color {
        theme.isDark ? Color.white : Color.black
    }

    private var actionForeground: Color {
        theme.isDark ? Color.black.opacity(0.86) : Color.white
    }
}

private struct AppearanceSettingsPane: View {
    @ObservedObject var settings: PillSettings

    var body: some View {
        SettingsDetailPage(
            title: "Appearance",
            subtitle: "Choose how the settings app follows your Mac."
        ) {
            SettingsSection("Theme") {
                ThemePicker(settings: settings)
                    .padding(12)
            }
        }
    }
}

private struct ThemePicker: View {
    @ObservedObject var settings: PillSettings
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppAppearance.allCases) { appearance in
                Button {
                    settings.appAppearance = appearance
                } label: {
                    VStack(spacing: 8) {
                        HugeIcon(appearance.icon, size: 22)
                        Text(appearance.title)
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(theme.foreground)
                    .frame(width: 92, height: 76)
                    .background(settings.appAppearance == appearance ? theme.selected : theme.background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(settings.appAppearance == appearance ? theme.foreground.opacity(0.42) : .clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .help("Use \(appearance.title.lowercased()) appearance")
                .pointingHandCursor()
            }
        }
    }
}

private struct CaptureSettingsPane: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        SettingsDetailPage(
            title: "Capture",
            subtitle: "Shortcuts used by the capture island."
        ) {
            SettingsSection("Shortcuts") {
                ShortcutRow(title: "Annotate screenshot", keys: ["Option"], detail: "Hold and move the pointer to draw.")
                RowDivider()
                ShortcutRow(title: "Clean screenshot", keys: ["Control", "Option"], detail: "Capture the active display without annotation.")
            }

            SettingsSection("Diagnostics") {
                VStack(spacing: 10) {
                    SettingsActionButton(title: "Test screenshot", icon: .camera) {
                        viewModel.testScreenshot()
                    }

                    SettingsActionButton(title: "Test annotation overlay", icon: .pen) {
                        viewModel.testOverlay()
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct ShortcutRow: View {
    let title: String
    let keys: [String]
    let detail: String
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.foreground)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            HStack(spacing: 5) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(theme.foreground)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(theme.background, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 60)
    }
}

private struct StorageSettingsPane: View {
    @State private var metrics = StorageMetrics.loading

    var body: some View {
        SettingsDetailPage(
            title: "Storage",
            subtitle: "Inspect the local library used by Assist."
        ) {
            SettingsSection("Library") {
                SettingValueRow(title: "Library size", value: metrics.librarySize)
            }

            SettingsActionButton(title: "Refresh storage", icon: .refresh) {
                refresh()
            }
        }
        .task {
            refresh()
        }
    }

    private func refresh() {
        Task {
            metrics = await StorageMetrics.current()
        }
    }
}

private struct StorageMetrics {
    let librarySize: String

    static let loading = StorageMetrics(
        librarySize: "Calculating..."
    )

    static var supportURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
    }

    static func current() async -> StorageMetrics {
        await Task.detached(priority: .utility) {
            let supportSize = directorySize(at: supportURL)

            return StorageMetrics(
                librarySize: ByteCountFormatter.string(fromByteCount: supportSize, countStyle: .file)
            )
        }.value
    }

    private static func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        return enumerator.compactMap { item -> Int64? in
            guard let fileURL = item as? URL,
                  let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true else {
                return nil
            }

            return Int64(resourceValues.fileSize ?? 0)
        }.reduce(0, +)
    }

}

private struct SettingToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.foreground)

            Spacer(minLength: 16)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(hex: 0x30D158))
                .controlSize(.small)
                .pointingHandCursor()
        }
        .frame(height: 42)
    }
}

private struct UpdatesSettingsPane: View {
    @ObservedObject var settings: PillSettings

    var body: some View {
        SettingsDetailPage(
            title: "Updates",
            subtitle: "Assist checks for updates in the background and installs them the next time you quit."
        ) {
            VStack(alignment: .leading, spacing: 0) {
                SettingToggleRow(
                    title: "Download updates automatically",
                    isOn: $settings.downloadUpdatesAutomatically
                )

                RowDivider()

                SettingsActionButton(title: "Check for updates", icon: .refresh) {
                    NSWorkspace.shared.open(AppIdentity.releasesURL)
                }
                .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AboutInfoRow: View {
    let title: String
    let value: String
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.muted)

            Spacer(minLength: 16)

            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.foreground.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
        .frame(height: 24)
    }
}

private struct AboutActionRow: View {
    let title: String
    let actionTitle: String
    let action: () -> Void
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.muted)

            Spacer(minLength: 16)

            Button(action: action) {
                Text(actionTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.foreground.opacity(0.82))
            }
            .buttonStyle(.plain)
            .help(actionTitle)
            .pointingHandCursor()
        }
        .frame(height: 24)
    }
}

private struct AboutSettingsPane: View {
    var body: some View {
        SettingsDetailPage(
            title: "About",
            subtitle: nil
        ) {
            VStack(alignment: .leading, spacing: 6) {
                AboutInfoRow(title: "Version", value: appVersion)
                AboutActionRow(title: "Privacy", actionTitle: "View policy") {
                    NSWorkspace.shared.open(AppIdentity.privacyPolicyURL)
                }
                AboutInfoRow(title: "Support", value: AppIdentity.supportEmail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return "v\(version)"
    }
}

private extension ClipboardHistoryItem {
    var dragProvider: NSItemProvider {
        switch self {
        case let .screenshot(capture):
            capture.dragProvider
        case let .text(textClip):
            textClip.dragProvider
        }
    }
}

private extension CaptureItem {
    var dragProvider: NSItemProvider {
        let imageURL = URL(fileURLWithPath: imagePath)

        if FileManager.default.fileExists(atPath: imageURL.path),
           let provider = NSItemProvider(contentsOf: imageURL) {
            return provider
        }

        return NSItemProvider(object: imagePath as NSString)
    }
}

private extension TextClipItem {
    var dragProvider: NSItemProvider {
        NSItemProvider(object: text as NSString)
    }
}
