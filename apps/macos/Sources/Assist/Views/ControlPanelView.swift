import AppKit
import SwiftUI

private typealias LibraryTokens = AssistDesignTokens.CaptureLibrary

struct ControlPanelView: View {
    @ObservedObject var settings: PillSettings
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var keyboardSounds: KeyboardSoundController
    @State private var selectedPage: SettingsPage = .capture
    @State private var isSettingsDialogPresented = false
    @State private var selectedFilter: ClipboardHistoryFilter = .all
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AssistAppSurface { theme in
            ZStack {
                HStack(spacing: 0) {
                    LibrarySidebar(
                        selectedFilter: $selectedFilter,
                        items: viewModel.historyItems,
                        openSettings: { isSettingsDialogPresented = true }
                    )
                    .frame(width: 196)

                    CaptureLibraryView(viewModel: viewModel, selectedFilter: $selectedFilter)
                        .background(theme.background)
                        .clipShape(RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.window))
                        .padding(.vertical, 8)
                        .padding(.trailing, 8)
                }
                .disabled(isSettingsDialogPresented)
                .accessibilityHidden(isSettingsDialogPresented)

                if isSettingsDialogPresented {
                    Color.black
                        .opacity(theme.isDark ? 0.42 : 0.32)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { isSettingsDialogPresented = false }

                    SettingsDialog {
                        isSettingsDialogPresented = false
                    } content: {
                        settingsView(theme: theme)
                    }
                    .frame(width: 820, height: 560)
                    .transition(.opacity)
                    .onExitCommand { isSettingsDialogPresented = false }
                }
            }
            .frame(minWidth: 920, minHeight: 660)
            .background(theme.sidebar)
            .ignoresSafeArea(.container, edges: .top)
            .animation(reduceMotion ? nil : AssistDesignTokens.Motion.quick, value: isSettingsDialogPresented)
        }
        .onAppear { viewModel.willShowHistory() }
    }

    private func settingsView(theme: AssistTheme) -> some View {
        HStack(alignment: .top, spacing: 28) {
            SettingsSidebar(selectedPage: $selectedPage)
                .frame(width: 196)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(22)
        .background(theme.background)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedPage {
        case .appearance:
            AppearanceSettingsPane(settings: settings)
        case .capture:
            CaptureSettingsPane(viewModel: viewModel)
        case .sounds:
            KeyboardSoundSettingsPane(controller: keyboardSounds)
        case .storage:
            StorageSettingsPane()
        case .updates:
            UpdatesSettingsPane(settings: settings, viewModel: viewModel)
        case .about:
            AboutSettingsPane()
        }
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case appearance
    case capture
    case sounds
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
        case .sounds:
            "Sounds"
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
        case .sounds:
            .sound
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

private struct CaptureLibraryView: View {
    @ObservedObject var viewModel: PillViewModel
    @Environment(\.assistTheme) private var theme
    @Binding var selectedFilter: ClipboardHistoryFilter

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: LibraryTokens.minimumCardWidth,
                    maximum: LibraryTokens.maximumCardWidth
                ),
                spacing: LibraryTokens.gridSpacing,
                alignment: .top
            )
        ]
    }

    private var filteredItems: [ClipboardHistoryItem] {
        viewModel.historyItems.filter(selectedFilter.includes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryWelcomeHeader()
                .padding(.horizontal, LibraryTokens.contentInset)
                .padding(.top, 32)
                .padding(.bottom, 24)

            if let issue = viewModel.captureIssue {
                CapturePermissionBanner(issue: issue, viewModel: viewModel)
                    .padding(.horizontal, LibraryTokens.contentInset)
                    .padding(.bottom, 18)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(selectedFilter == .all ? "History" : selectedFilter.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text("\(filteredItems.count.formatted()) items")
                    .font(AssistFont.caption())
                    .foregroundStyle(theme.muted)
                Text("Most recent")
                    .font(AssistFont.caption())
                    .foregroundStyle(theme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.control, in: Capsule())
            }
            .padding(.horizontal, LibraryTokens.contentInset)
            .padding(.bottom, 4)

            if viewModel.historyItems.isEmpty {
                EmptyCaptureLibraryView()
            } else if filteredItems.isEmpty {
                EmptyFilteredLibraryView(filter: selectedFilter)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: LibraryTokens.gridSpacing) {
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
                    .padding(LibraryTokens.contentInset)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

private struct CapturePermissionBanner: View {
    let issue: CaptureIssue
    @ObservedObject var viewModel: PillViewModel
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            HugeIcon(.desktop, size: 18, color: theme.foreground)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title)
                    .font(AssistFont.small(.semibold))
                    .foregroundStyle(theme.foreground)

                Text(issue.detail ?? issue.message)
                    .font(AssistFont.roundedFootnote(.medium))
                    .foregroundStyle(theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button(issue.primaryActionTitle) {
                viewModel.perform(issue.primaryAction)
            }
            .buttonStyle(AssistButtonStyle(emphasis: .primary, height: 32))

            if let secondaryActionTitle = issue.secondaryActionTitle,
               let secondaryAction = issue.secondaryAction {
                Button(secondaryActionTitle) {
                    viewModel.perform(secondaryAction)
                }
                .buttonStyle(AssistButtonStyle(height: 32))
            }
        }
        .padding(16)
        .background(theme.accentSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct EmptyFilteredLibraryView: View {
    let filter: ClipboardHistoryFilter
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Text("No \(filter.title.lowercased()) yet")
                .font(.headline)
                .foregroundStyle(theme.foreground)

            Text("Switch to All to see every saved item.")
                .font(AssistFont.caption())
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
                .font(AssistFont.caption())
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }
}

private struct CaptureLibraryCard: View {
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
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: LibraryTokens.cardHeight)
                .background(
                    cardBackground,
                    in: RoundedRectangle(cornerRadius: LibraryTokens.cardRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LibraryTokens.cardRadius, style: .continuous)
                        .stroke(
                            isSelected ? theme.accent : theme.border,
                            lineWidth: LibraryTokens.selectionStroke
                        )
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: LibraryTokens.cardRadius, style: .continuous)
                )
                .shadow(color: .black.opacity(theme.isDark ? 0.08 : 0.025), radius: 4, y: 2)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .onDrag { item.dragProvider }
            .help(helpText)

            DeleteIconButton(isHovered: $isDeleteHovered, action: deleteAction)
                .opacity(isDeleteVisible ? 1 : 0)
                .allowsHitTesting(isDeleteVisible)
                .accessibilityHidden(!isDeleteVisible)
                .zIndex(1)
                .padding(LibraryTokens.actionInset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: LibraryTokens.cardHeight)
        .contentShape(
            RoundedRectangle(cornerRadius: LibraryTokens.cardRadius, style: .continuous)
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    @ViewBuilder
    private var preview: some View {
        switch item {
        case .screenshot:
            GeometryReader { geometry in
                ZStack {
                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()
                    } else {
                        HugeIcon(.image, size: 30)
                            .foregroundStyle(theme.muted)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
        case let .text(textClip):
            if let colorCode = textClip.colorCode {
                ZStack(alignment: .bottomLeading) {
                    Color(clipboardColor: colorCode)

                    Text(colorCode.displayValue)
                        .font(AssistFont.mono())
                        .foregroundStyle(
                            colorCode.usesDarkForeground(over: theme.cardColorComponents)
                                ? AssistDesignTokens.Palette.ink
                                : AssistDesignTokens.Palette.paper
                        )
                        .padding(AssistDesignTokens.Spacing.large)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HugeIcon(.document, size: 18)
                        .foregroundStyle(theme.muted)
                    Text(textClip.preview)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .foregroundStyle(theme.foreground)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var cardBackground: Color {
        if isSelected { return theme.accentSurface }
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

    var body: some View {
        Button(action: action) {
            HugeIcon(
                .trash,
                size: 15,
                color: AssistDesignTokens.Palette.danger.opacity(
                    isHovered ? 1 : AssistDesignTokens.Opacity.primary
                )
            )
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
        if isHovered {
            return AssistDesignTokens.Palette.danger.opacity(
                AssistDesignTokens.Opacity.destructiveHoverSurface
            )
        }

        return .clear
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedPage: SettingsPage
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, 11)
                .padding(.top, 7)
                .padding(.bottom, 20)

            ForEach(SettingsPage.allCases) { page in
                AssistNavigationRow(title: page.title, icon: page.icon, isSelected: page == selectedPage) {
                    selectedPage = page
                }
            }

            Spacer()

            HStack(spacing: 8) {
                AssistLogo(size: 20)
                Text("Assist")
                    .font(AssistFont.small())
                    .foregroundStyle(theme.muted)
            }
            .padding(11)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct RowDivider: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.border)
            .frame(height: 1)
            .padding(.horizontal, 16)
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
                    .font(.system(size: 13))
                    .foregroundStyle(theme.foreground)
                if let detail {
                    Text(detail)
                        .font(AssistFont.caption())
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                HugeIcon(icon, size: 14)
                Text(title)
            }
        }
        .buttonStyle(AssistButtonStyle())
        .help(title)
    }
}

private struct AppearanceSettingsPane: View {
    @ObservedObject var settings: PillSettings

    var body: some View {
        SettingsDetailPage(
            title: "Appearance",
            subtitle: "Choose how Assist looks, from launch to your library."
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
                        HugeIcon(appearance.icon, size: 22, color: settings.appAppearance == appearance ? theme.accent : theme.foreground)
                        Text(appearance.title)
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(theme.foreground)
                    .frame(width: 92, height: 76)
                    .background(settings.appAppearance == appearance ? theme.accentSurface : theme.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(settings.appAppearance == appearance ? theme.accent.opacity(0.5) : .clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(settings.appAppearance == appearance ? .isSelected : [])
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

            VoiceContextSettings(
                settings: viewModel.settings,
                viewModel: viewModel,
                service: viewModel.voiceContextService
            )

            SettingsSection("Diagnostics") {
                VStack(spacing: 10) {
                    SettingsActionButton(title: "Test screenshot", icon: .camera) {
                        viewModel.testScreenshot()
                    }

                    SettingsActionButton(title: "Test annotation overlay", icon: .pen) {
                        viewModel.testOverlay()
                    }

                    SettingsActionButton(title: "Request screen access", icon: .desktop) {
                        viewModel.requestScreenRecordingPermission()
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct VoiceContextSettings: View {
    @ObservedObject var settings: PillSettings
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var service: VoiceContextService
    @Environment(\.assistTheme) private var theme

    var body: some View {
        SettingsSection("Voice context") {
            VStack(alignment: .leading, spacing: 12) {
                if service.canRecord {
                    SettingToggleRow(
                        title: "Dictate while annotating",
                        detail: "Records only while Option is held, transcribes locally in English, and never saves audio.",
                        isOn: $settings.voiceContextEnabled
                    )
                } else {
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(modelStatusTitle)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.foreground)
                            Text(modelStatusDetail)
                                .font(.caption)
                                .foregroundStyle(theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        if canStartSetup {
                            SettingsActionButton(title: setupButtonTitle, icon: .refresh) {
                                viewModel.setUpVoiceContext()
                            }
                        }
                    }

                    if case let .downloading(progress) = service.modelState {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    } else if service.modelState == .preparing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text("Assist does not inspect, summarize, redact, or upload screenshot contents. Copying is always an explicit action.")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Copy Context includes your screenshot and notes. Use Copy Screenshot when you only need the image.")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
    }

    private var canStartSetup: Bool {
        switch service.modelState {
        case .notInstalled, .failed, .ready:
            true
        case .unsupported, .downloading, .preparing:
            false
        }
    }

    private var setupButtonTitle: String {
        if service.modelState == .ready {
            if service.microphoneAccessState == .denied {
                return "Open microphone settings"
            }
            return service.audioInputError == nil ? "Allow microphone" : "Retry audio input"
        }
        return "Set up (~487 MB)"
    }

    private var modelStatusTitle: String {
        switch service.modelState {
        case .unsupported:
            "Apple Silicon required"
        case .notInstalled:
            "Voice context is not set up"
        case let .downloading(progress):
            "Downloading Whisper… \(Int(progress * 100))%"
        case .preparing:
            "Preparing Whisper…"
        case .ready:
            service.audioInputError == nil ? "Microphone access needed" : "Audio input unavailable"
        case .failed:
            "Voice context setup failed"
        }
    }

    private var modelStatusDetail: String {
        switch service.modelState {
        case .unsupported:
            "This first release supports Apple Silicon Macs only."
        case .notInstalled:
            "Download the English voice model once to transcribe on your Mac."
        case .downloading:
            "The voice model is downloading to your Mac."
        case .preparing:
            "Preparing local transcription."
        case .ready:
            service.audioInputError
                ?? "The model is installed. Allow microphone access to finish setup."
        case let .failed(detail):
            detail
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
                    .font(.system(size: 13))
                    .foregroundStyle(theme.foreground)
                Text(detail)
                    .font(AssistFont.caption())
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            HStack(spacing: 5) {
                ForEach(keys, id: \.self) { key in
                    AssistKeycap(title: key)
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

private struct UpdatesSettingsPane: View {
    @ObservedObject var settings: PillSettings
    @ObservedObject var viewModel: PillViewModel
    @Environment(\.assistTheme) private var theme

    var body: some View {
        SettingsDetailPage(
            title: "Updates",
            subtitle: "Check for a new macOS release and install it immediately when one is available."
        ) {
            SettingsSection("Software updates") {
                SettingToggleRow(
                    title: "Download updates automatically",
                    isOn: $settings.downloadUpdatesAutomatically
                )

                RowDivider()

                VStack(alignment: .leading, spacing: 10) {
                    SettingsActionButton(title: viewModel.isCheckingForUpdates ? "Checking..." : "Check for updates", icon: .refresh) {
                        viewModel.checkForUpdates()
                    }
                    .disabled(viewModel.isCheckingForUpdates)
                    .opacity(viewModel.isCheckingForUpdates ? 0.62 : 1)

                    if let updateStatusText = viewModel.updateStatusText {
                        HStack(alignment: .top, spacing: 8) {
                            if viewModel.isCheckingForUpdates {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.top, 1)
                            }

                            Text(updateStatusText)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                .font(.system(size: 13))
                .foregroundStyle(theme.muted)

            Spacer(minLength: 16)

            Text(value)
                .font(.system(size: 13))
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
                .font(.system(size: 13))
                .foregroundStyle(theme.muted)

            Spacer(minLength: 16)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 13))
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
            SettingsSection("Assist for macOS") {
                VStack(alignment: .leading, spacing: 12) {
                    AboutInfoRow(title: "Version", value: appVersion)
                    AboutActionRow(title: "Privacy", actionTitle: "View policy") {
                        NSWorkspace.shared.open(AppIdentity.privacyPolicyURL)
                    }
                    AboutInfoRow(title: "Support", value: AppIdentity.supportEmail)
                }
                .padding(16)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return "v\(version)"
    }
}
