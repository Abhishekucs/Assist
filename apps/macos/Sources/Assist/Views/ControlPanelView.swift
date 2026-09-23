import AppKit
import SwiftUI

private typealias LibraryTokens = AssistDesignTokens.CaptureLibrary

struct ControlPanelView: View {
    /// Also the window's minimum size; the hosting view derives it from this frame.
    static let minimumSize = CGSize(width: 920, height: 660)

    @ObservedObject var settings: PillSettings
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var keyboardSounds: KeyboardSoundController
    let modules: ModuleServices
    @State private var selectedPage: SettingsPage = .capture
    @State private var selectedModule: AssistModule?
    @State private var isSettingsDialogPresented = false
    @State private var selectedFilter: LibraryContentFilter = .all
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AssistAppSurface { theme in
            ZStack {
                HStack(spacing: 0) {
                    LibrarySidebar(
                        selectedModule: $selectedModule,
                        openSettings: { isSettingsDialogPresented = true }
                    )

                    // The library sits below the title bar; only its pane
                    // surface (behind) reaches up under it.
                    Group {
                        if let selectedModule {
                            ModulesSettingsPane(
                                module: selectedModule,
                                viewModel: viewModel,
                                modules: modules
                            )
                            .padding(Tokens.Spacing.xxxLarge)
                        } else {
                            CaptureLibraryView(viewModel: viewModel, selectedFilter: $selectedFilter)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipShape(
                        UnevenRoundedRectangle(
                            bottomLeadingRadius: Tokens.Radius.window,
                            bottomTrailingRadius: Tokens.Radius.window
                        )
                    )
                    .padding(.bottom, Tokens.AppLayout.paneInset)
                    .padding(.trailing, Tokens.AppLayout.paneInset)
                }
                .background {
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: Tokens.AppLayout.sidebarWidth)
                        RoundedRectangle(cornerRadius: Tokens.Radius.window)
                            .fill(theme.background)
                            .padding(.vertical, Tokens.AppLayout.paneInset)
                            .padding(.trailing, Tokens.AppLayout.paneInset)
                    }
                    .ignoresSafeArea()
                }
                .disabled(isSettingsDialogPresented)
                .accessibilityHidden(isSettingsDialogPresented)

                if isSettingsDialogPresented {
                    Color.black
                        .opacity(theme.isDark ? 0.42 : 0.32)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { isSettingsDialogPresented = false }
                        .accessibilityHidden(true)

                    SettingsDialog {
                        isSettingsDialogPresented = false
                    } content: {
                        settingsView
                    }
                    .frame(width: Tokens.Settings.dialogSize.width, height: Tokens.Settings.dialogSize.height)
                    .transition(.opacity)
                }
            }
            .titleBarSafeArea()
            .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
            .background(theme.sidebar)
            .animation(reduceMotion ? nil : Tokens.Motion.quick, value: isSettingsDialogPresented)
        }
        .onAppear { viewModel.willShowHistory() }
    }

    private var settingsView: some View {
        HStack(alignment: .top, spacing: Tokens.Settings.columnSpacing) {
            SettingsSidebar(selectedPage: $selectedPage)
                .frame(width: Tokens.AppLayout.sidebarWidth)

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(Tokens.Settings.dialogInset)
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
    @Binding var selectedFilter: LibraryContentFilter
    @Environment(\.assistTheme) private var theme

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

    var body: some View {
        let filteredItems = viewModel.historyItems.filter(selectedFilter.includes)
        let selectedID = viewModel.selectedItem?.id
        VStack(alignment: .leading, spacing: 0) {
            LibraryWelcomeHeader()
                .padding(.horizontal, LibraryTokens.contentInset)
                .padding(.top, LibraryTokens.headerTopInset)
                .padding(.bottom, LibraryTokens.contentInset)

            if let issue = viewModel.captureIssue {
                CapturePermissionBanner(issue: issue, viewModel: viewModel)
                    .padding(.horizontal, LibraryTokens.contentInset)
                    .padding(.bottom, Tokens.Spacing.xxLarge)
            }

            historyHeader(count: filteredItems.count)

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
                                isSelected: item.id == selectedID,
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
    }

    private func historyHeader(count: Int) -> some View {
        let countText = count == 1 ? "1 item" : "\(count.formatted()) items"
        return HStack(alignment: .center, spacing: Tokens.Spacing.medium) {
            Text("History")
                .font(Tokens.Typography.sectionTitle)
                .foregroundStyle(theme.foreground)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Picker("Content", selection: $selectedFilter) {
                ForEach(LibraryContentFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityLabel("Filter library content")
            Text(countText)
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
        }
        .padding(.horizontal, LibraryTokens.contentInset)
        .padding(.bottom, Tokens.Spacing.xxSmall)
    }

    private func thumbnail(for item: ClipboardHistoryItem) -> NSImage? {
        guard case let .screenshot(capture) = item else { return nil }
        return viewModel.thumbnail(for: capture)
    }

    private func select(_ item: ClipboardHistoryItem) {
        switch item {
        case let .screenshot(capture):
            viewModel.copyImageItem(capture)
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
        HStack(alignment: .center, spacing: Tokens.Spacing.xLarge) {
            HugeIcon(.desktop, size: Tokens.Icon.feedback, color: theme.foreground)
                .frame(width: Tokens.Control.compactHeight, height: Tokens.Control.compactHeight)

            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxSmall) {
                Text(issue.title)
                    .font(Tokens.Typography.small(.semibold))
                    .foregroundStyle(theme.foreground)

                Text(issue.detail ?? issue.message)
                    .font(Tokens.Typography.footnote(.medium))
                    .foregroundStyle(theme.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Tokens.Spacing.large)

            Button(issue.primaryActionTitle) {
                viewModel.perform(issue.primaryAction)
            }
            .buttonStyle(AssistButtonStyle(emphasis: .primary, height: Tokens.Control.mediumHeight))

            if let secondaryActionTitle = issue.secondaryActionTitle,
               let secondaryAction = issue.secondaryAction {
                Button(secondaryActionTitle) {
                    viewModel.perform(secondaryAction)
                }
                .buttonStyle(AssistButtonStyle(height: Tokens.Control.mediumHeight))
            }
        }
        .padding(16)
        .background(theme.accentSurface, in: RoundedRectangle(cornerRadius: Tokens.Radius.large))
    }
}

private struct EmptyFilteredLibraryView: View {
    let filter: LibraryContentFilter
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(spacing: Tokens.Spacing.small) {
            Text(filter.emptyTitle)
                .font(Tokens.Typography.pageTitle)
                .foregroundStyle(theme.foreground)

            Text("Select All to see every saved item.")
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyCaptureLibraryView: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(spacing: Tokens.Spacing.xLarge) {
            HugeIcon(ClipboardHistoryFilter.all.emptyIcon, size: Tokens.Icon.emptyState, color: theme.muted)

            Text(ClipboardHistoryFilter.all.emptyTitle)
                .font(Tokens.Typography.pageTitle)
                .foregroundStyle(theme.foreground)

            // The shortcuts are already shown in the header above.
            Text("Screenshots, copied images, text, and links will appear here.")
                .font(Tokens.Typography.caption())
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        let shape = RoundedRectangle(cornerRadius: LibraryTokens.cardRadius, style: .continuous)
        ZStack(alignment: .topTrailing) {
            Button(action: selectAction) {
                preview
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: LibraryTokens.cardHeight)
                    .background(Color(rgb: backgroundComponents), in: shape)
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(
                            isSelected ? theme.accent : theme.border,
                            lineWidth: isSelected ? LibraryTokens.selectionStroke : LibraryTokens.borderStroke
                        )
                    }
                    // An inner ring keeps the selection visible on a clipboard
                    // color that matches the accent.
                    .overlay {
                        if isSelected {
                            shape
                                .inset(by: LibraryTokens.selectionStroke)
                                .strokeBorder(theme.background, lineWidth: LibraryTokens.borderStroke)
                        }
                    }
                    .shadow(color: .black.opacity(theme.isDark ? 0.08 : 0.025), radius: 4, y: 2)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .animation(Tokens.Motion.quick, value: isHovered)
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
                        HugeIcon(.image, size: Tokens.Icon.placeholder, color: theme.muted)
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
                        .font(Tokens.Typography.mono)
                        .foregroundStyle(
                            colorCode.usesDarkForeground(over: backgroundComponents)
                                ? Tokens.Palette.ink
                                : Tokens.Palette.paper
                        )
                        .padding(Tokens.Spacing.large)
                }
            } else {
                VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
                    HugeIcon(textClip.linkURL == nil ? .document : .file, size: Tokens.Icon.feedback, color: theme.muted)
                    Text(textClip.preview)
                        .font(Tokens.Typography.label())
                        .lineSpacing(3)
                        .foregroundStyle(theme.foreground)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                .padding(Tokens.Spacing.xLarge)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    /// The opaque surface behind the preview. A translucent clipboard color
    /// blends over it, so its label color is judged against this, too.
    private var backgroundComponents: RGBColorComponents {
        if isSelected { return theme.accentSurfaceComponents }
        if isHovered { return theme.controlComponents }
        return theme.cardComponents
    }

    private var helpText: String {
        switch item {
        case .screenshot:
            "Copy image"
        case .text:
            "Copy text or link"
        }
    }
}

private struct DeleteIconButton: View {
    @Binding var isHovered: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.iconButton, style: .continuous)
        Button(action: action) {
            HugeIcon(
                .trash,
                size: Tokens.Icon.medium,
                color: Tokens.Palette.danger.opacity(isHovered ? 1 : Tokens.Opacity.primary)
            )
            .frame(width: Tokens.Control.largeIconButton, height: Tokens.Control.largeIconButton)
            // Icon-only buttons stay transparent until hovered (AGENTS.md);
            // delete shows a light red hover background.
            .background(hoverTint, in: shape)
        }
        .buttonStyle(.plain)
        .help("Delete item")
        .accessibilityLabel("Delete item")
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(Tokens.Motion.quick, value: isHovered)
    }

    private var hoverTint: Color {
        isHovered
            ? Tokens.Palette.danger.opacity(Tokens.Opacity.destructiveHoverSurface)
            : .clear
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedPage: SettingsPage
    @Environment(\.assistTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
            Text("Settings")
                .font(Tokens.Typography.sectionTitle)
                .foregroundStyle(theme.foreground)
                .padding(.horizontal, Tokens.AppLayout.sidebarInset)
                .padding(.top, Tokens.Settings.headerTopInset)
                .padding(.bottom, 20)
                .accessibilityAddTraits(.isHeader)

            ForEach(SettingsPage.allCases) { page in
                AssistNavigationRow(title: page.title, icon: page.icon, isSelected: page == selectedPage) {
                    selectedPage = page
                }
            }

            Spacer()

            HStack(spacing: Tokens.Spacing.small) {
                AssistLogo(size: 20)
                Text("Assist")
                    .font(Tokens.Typography.small())
                    .foregroundStyle(theme.muted)
            }
            .padding(Tokens.AppLayout.sidebarInset)
            .accessibilityElement(children: .combine)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct RowDivider: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(theme.border)
            .frame(height: Tokens.Control.borderWidth)
            .padding(.horizontal, Tokens.Settings.rowInset)
    }
}

private struct SettingsActionButton: View {
    let title: String
    let icon: HugeIconKind
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.small) {
                // A busy button stays legible, so it shows its progress in place.
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: Tokens.Icon.regular, height: Tokens.Icon.regular)
                } else {
                    HugeIcon(icon, size: Tokens.Icon.regular)
                }
                Text(title)
            }
        }
        .buttonStyle(AssistButtonStyle(isBusy: isBusy))
        .disabled(isBusy)
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
                SettingsControlGroup {
                    ThemePicker(settings: settings)
                }
            }
        }
    }
}

private struct ThemePicker: View {
    @ObservedObject var settings: PillSettings
    @Environment(\.assistTheme) private var theme

    var body: some View {
        HStack(spacing: Tokens.Spacing.medium) {
            ForEach(AppAppearance.allCases) { appearance in
                tile(for: appearance, isSelected: settings.appAppearance == appearance)
            }
        }
    }

    private func tile(for appearance: AppAppearance, isSelected: Bool) -> some View {
        Button {
            settings.appAppearance = appearance
        } label: {
            VStack(spacing: Tokens.Spacing.small) {
                HugeIcon(appearance.icon, size: Tokens.Icon.tile, color: isSelected ? theme.accent : theme.foreground)
                Text(appearance.title)
                    .font(Tokens.Typography.label(isSelected ? .medium : .regular))
            }
            .foregroundStyle(theme.foreground)
            .frame(width: 92, height: 76)
            .assistOptionTile(isSelected: isSelected)
            // A check mark marks the selection without relying on color.
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    HugeIcon(.check, size: Tokens.Icon.small, color: theme.accent)
                        .padding(Tokens.Spacing.xSmall)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("Use \(appearance.title.lowercased()) appearance")
        .pointingHandCursor()
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
                ForEach(Array(CaptureShortcut.all.enumerated()), id: \.element.id) { index, shortcut in
                    if index > 0 {
                        RowDivider()
                    }
                    SettingsRow(shortcut.title, detail: shortcut.detail) {
                        AssistKeycapRow(keys: shortcut.keyNames)
                    }
                }
            }

            VoiceContextSettings(
                settings: viewModel.settings,
                viewModel: viewModel,
                service: viewModel.voiceContextService
            )

            SettingsSection("Diagnostics") {
                SettingsControlGroup {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
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
                }
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
            if service.canRecord {
                SettingToggleRow(
                    title: "Dictate while annotating",
                    detail: "Records only while Option is held, transcribes locally in English, and never saves audio.",
                    isOn: $settings.voiceContextEnabled
                )
            } else {
                SettingsControlGroup {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
                        HStack(alignment: .center, spacing: Tokens.Spacing.xLarge) {
                            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                                Text(modelStatusTitle)
                                    .font(Tokens.Typography.label())
                                    .foregroundStyle(theme.foreground)
                                Text(modelStatusDetail)
                                    .font(Tokens.Typography.caption())
                                    .foregroundStyle(theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: Tokens.Spacing.large)

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
                }
            }

            RowDivider()

            SettingsControlGroup {
                VStack(alignment: .leading, spacing: Tokens.Spacing.large) {
                    Text("Assist does not inspect, summarize, redact, or upload screenshot contents. Copying is always an explicit action.")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Every new capture stores a Markdown context beside its screenshot. Copy Context sends that exact Markdown and the original image to macOS. Each destination decides whether it accepts multiple pasteboard items; Copy Screenshot remains the manual fallback.")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
        return "Set up (~\(VoiceContextService.modelDownloadMegabytes) MB)"
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

    /// Setup copy names the model's source and storage, since setup is a
    /// third-party download while captures themselves stay local.
    private var modelStatusDetail: String {
        switch service.modelState {
        case .unsupported:
            "This first release supports Apple Silicon Macs only."
        case .notInstalled:
            "Downloads \(VoiceContextService.modelIdentifier) (\(VoiceContextService.modelDownloadSizeDescription)) "
                + "from Hugging Face to \(modelsLocation), then transcribes on your Mac."
        case .downloading:
            "Downloading from Hugging Face to \(modelsLocation)."
        case .preparing:
            "Core ML is loading the downloaded model on your Mac."
        case .ready:
            service.audioInputError
                ?? "The model is installed. Allow microphone access to finish setup."
        case let .failed(detail):
            detail
        }
    }

    private var modelsLocation: String {
        (service.modelsDirectory.path as NSString).abbreviatingWithTildeInPath
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
                SettingsRow("Library size") {
                    SettingsValueText(metrics.librarySize)
                }
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

                SettingsControlGroup {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
                        SettingsActionButton(
                            title: viewModel.isCheckingForUpdates ? "Checking..." : "Check for updates",
                            icon: .refresh,
                            isBusy: viewModel.isCheckingForUpdates
                        ) {
                            viewModel.checkForUpdates()
                        }

                        if let updateStatusText = viewModel.updateStatusText {
                            Text(updateStatusText)
                                .font(Tokens.Typography.small(.medium))
                                .foregroundStyle(theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }
                    }
                }
            }
        }
    }
}

private struct AboutSettingsPane: View {
    @Environment(\.assistTheme) private var theme

    var body: some View {
        SettingsDetailPage(
            title: "About",
            subtitle: nil
        ) {
            SettingsSection("Assist for macOS") {
                SettingsRow("Version") {
                    SettingsValueText(appVersion)
                }
                RowDivider()
                SettingsRow("Privacy") {
                    Link("View policy", destination: AppIdentity.privacyPolicyURL)
                        .font(Tokens.Typography.label())
                        .foregroundStyle(theme.accent)
                }
                RowDivider()
                SettingsRow("Support") {
                    SettingsValueText(AppIdentity.supportEmail)
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        return "v\(version)"
    }
}
