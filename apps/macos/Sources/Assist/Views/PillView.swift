import AppKit
import SwiftUI

private typealias HistoryShelfTokens = AssistDesignTokens.HistoryShelf

struct PillView: View {
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var settings: PillSettings
    @ObservedObject var moduleSettings: ModuleSettings
    let modules: ModuleServices
    let onHoverChanged: (Bool) -> Void
    let onIslandDragChanged: (Bool) -> Void

    private var isIslandChromeVisible: Bool {
        viewModel.isExpanded
    }

    private var chromeSize: CGSize {
        viewModel.isExpanded ? expandedSize : collapsedSize
    }

    private var collapsedSize: CGSize {
        PillChromeMetrics.collapsedSize(settings: settings)
    }

    private var expandedSize: CGSize {
        PillChromeMetrics.expandedSize(
            settings: settings,
            enabledModuleCount: moduleSettings.enabledModules.count
        )
    }

    private var chromeTopCornerRadius: CGFloat {
        PillChromeMetrics.topCornerRadius(forExpandedState: isIslandChromeVisible)
    }

    private var chromeBottomCornerRadius: CGFloat {
        PillChromeMetrics.bottomCornerRadius(forExpandedState: isIslandChromeVisible)
    }

    private var islandAnimation: Animation {
        AssistDesignTokens.Motion.island
    }

    private var shouldShowLoadingBorder: Bool {
        settings.showLoadingBorder && viewModel.isBusy
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if viewModel.isCollapsedContentVisible {
                    CollapsedIslandHeader(
                        viewModel: viewModel,
                        moduleSettings: moduleSettings,
                        timers: modules.timers
                    )
                        .frame(
                            width: collapsedSize.width,
                            height: collapsedSize.height
                        )
                        .transition(.opacity.animation(.easeOut(duration: 0.08)))
                }

                if viewModel.isExpandedContentVisible {
                    ModuleIslandView(
                        viewModel: viewModel,
                        moduleSettings: moduleSettings,
                        modules: modules,
                        islandWidth: expandedSize.width,
                        onDragChanged: islandDragChanged
                    )
                        .frame(
                            width: expandedSize.width,
                            height: expandedSize.height,
                            alignment: .top
                        )
                        .allowsHitTesting(true)
                        .transition(
                            .opacity
                                .combined(with: .scale(scale: 0.985, anchor: .top))
                                .animation(.easeOut(duration: 0.1))
                        )
                        .transaction { transaction in
                            transaction.animation = nil
                            transaction.disablesAnimations = true
                        }
                }
            }
            .frame(width: chromeSize.width, height: chromeSize.height, alignment: .top)
            .animation(islandAnimation, value: viewModel.isExpanded)
            .background {
                BoringNotchShape(
                    topCornerRadius: chromeTopCornerRadius,
                    bottomCornerRadius: chromeBottomCornerRadius
                )
                    .fill(Color.black)
                    .animation(islandAnimation, value: chromeTopCornerRadius)
                    .animation(islandAnimation, value: chromeBottomCornerRadius)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.black)
                    .frame(height: 1)
                    .padding(.horizontal, chromeTopCornerRadius)
            }
            .overlay {
                if shouldShowLoadingBorder {
                    MovingNotchBorder(
                        topCornerRadius: chromeTopCornerRadius,
                        bottomCornerRadius: chromeBottomCornerRadius
                    )
                    .transition(.opacity.animation(.easeOut(duration: 0.12)))
                }
            }
            .clipShape(
                BoringNotchShape(
                    topCornerRadius: chromeTopCornerRadius,
                    bottomCornerRadius: chromeBottomCornerRadius
                )
            )
            .contentShape(
                BoringNotchShape(
                    topCornerRadius: chromeTopCornerRadius,
                    bottomCornerRadius: chromeBottomCornerRadius
                )
            )
            .onHover(perform: onHoverChanged)
            .dropDestination(for: URL.self) { urls, _ in
                acceptDroppedFiles(urls)
            } isTargeted: { isTargeted in
                fileDropTargetChanged(isTargeted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }

    private func islandDragChanged(_ isDragging: Bool) {
        viewModel.isDraggingFromIsland = isDragging
        onIslandDragChanged(isDragging)
    }

    /// Files dragged onto the notch open the island on the module that takes
    /// them: the selected one when it accepts files, otherwise the shelf.
    private func fileDropTargetChanged(_ isTargeted: Bool) {
        guard !viewModel.isDraggingFromIsland,
              let target = moduleSettings.fileDropTarget,
              viewModel.isFileDropTargeted != isTargeted else { return }

        if isTargeted, moduleSettings.selectedModule != target {
            moduleSettings.selectedModule = target
        }
        viewModel.isFileDropTargeted = isTargeted
        onIslandDragChanged(isTargeted)
    }

    private func acceptDroppedFiles(_ urls: [URL]) -> Bool {
        let fileURLs = urls.filter(\.isFileURL)
        guard !viewModel.isDraggingFromIsland,
              !fileURLs.isEmpty,
              let target = moduleSettings.fileDropTarget else { return false }

        switch target {
        case .converter:
            modules.converter.convert(fileURLs)
        default:
            modules.shelf.add(fileURLs)
        }
        return true
    }
}

// The idle island is deliberately quiet. Short-lived feedback is text-led and
// anchored to the leading edge; a running timer shows on the trailing edge.
private struct CollapsedIslandHeader: View {
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var moduleSettings: ModuleSettings
    @ObservedObject var timers: FocusTimerService

    private var feedbackAnimation: Animation {
        AssistDesignTokens.Motion.feedback
    }

    private var showsTimer: Bool {
        moduleSettings.isEnabled(.timers) && timers.clock.hasStarted
    }

    var body: some View {
        HStack(spacing: 0) {
            if let feedback = viewModel.copyFeedback {
                Text(feedback.badge)
                    .font(AssistDesignTokens.Typography.footnote(.semibold))
                    .foregroundStyle(feedbackForeground(for: feedback.kind))
                    .lineLimit(1)
                    .opacity(viewModel.isCopyFeedbackVisible ? 1 : 0)
                    .transition(.opacity)
                    .help("\(feedback.badge): \(feedback.preview)")
                    .accessibilityLabel("\(feedback.badge). \(feedback.preview)")
            }

            Spacer(minLength: 0)

            if showsTimer {
                Text(timers.displayTime)
                    .font(AssistDesignTokens.Typography.footnote(.semibold).monospacedDigit())
                    .foregroundStyle(
                        AssistDesignTokens.Mono.ink.opacity(
                            timers.isRunning ? AssistDesignTokens.Opacity.strong : AssistDesignTokens.Opacity.muted
                        )
                    )
                    .lineLimit(1)
                    .transition(.opacity)
                    .accessibilityLabel("\(timers.mode.title) \(timers.displayTime)")
            }
        }
        .padding(.horizontal, AssistDesignTokens.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(feedbackAnimation, value: viewModel.copyFeedback)
        .animation(feedbackAnimation, value: viewModel.isCopyFeedbackVisible)
        .animation(feedbackAnimation, value: showsTimer)
    }

    private func feedbackForeground(for kind: CopyFeedback.Kind) -> Color {
        switch kind {
        case .success:
            AssistDesignTokens.Palette.paper.opacity(AssistDesignTokens.Opacity.strong)
        case .warning:
            AssistDesignTokens.Palette.warning
        }
    }
}

private struct MovingNotchBorder: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    private let segmentLength = 0.34

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let progress = time.truncatingRemainder(dividingBy: 1.55) / 1.55
            let start = max(0, progress - segmentLength)

            ZStack {
                LoadingNotchBorderShape(
                    topCornerRadius: topCornerRadius,
                    bottomCornerRadius: bottomCornerRadius
                )
                .stroke(
                    Color(red: 1.0, green: 0.28, blue: 0.05).opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )

                LoadingNotchBorderShape(
                    topCornerRadius: topCornerRadius,
                    bottomCornerRadius: bottomCornerRadius
                )
                .trim(from: start, to: progress)
                .loadingGlow()

                if progress < segmentLength {
                    LoadingNotchBorderShape(
                        topCornerRadius: topCornerRadius,
                        bottomCornerRadius: bottomCornerRadius
                    )
                    .trim(from: 1 - (segmentLength - progress), to: 1)
                    .loadingGlow()
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private extension Shape {
    func loadingGlow() -> some View {
        let gradient = LinearGradient(
            stops: [
                .init(color: Color(red: 1.0, green: 0.12, blue: 0.04).opacity(0.2), location: 0.0),
                .init(color: Color(red: 1.0, green: 0.18, blue: 0.04), location: 0.32),
                .init(color: Color(red: 1.0, green: 0.56, blue: 0.05), location: 0.68),
                .init(color: Color(red: 1.0, green: 0.2, blue: 0.04).opacity(0.3), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        return self
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .fill(gradient)
            .overlay {
                self
                    .stroke(style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .fill(gradient)
                    .blur(radius: 2.2)
            }
    }
}

private struct LoadingNotchBorderShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            AnimatablePair(topCornerRadius, bottomCornerRadius)
        }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let topRadius = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomCornerRadius, rect.width / 2, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius))
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius + bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius - bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius))

        return path
    }
}

/// The Clipboard module: the original capture shelf of screenshots and copied text.
struct ClipboardModuleView: View {
    @ObservedObject var viewModel: PillViewModel
    let onDragChanged: (Bool) -> Void
    @State private var selectedFilter: ClipboardHistoryFilter = .all

    var body: some View {
        let filteredItems = viewModel.historyItems(matching: selectedFilter)
        let historyItems = Array(filteredItems.prefix(24))
        let selectedHistoryID = viewModel.selectedItem?.id
        let visibleSelectedItem = historyItems.first { $0.id == selectedHistoryID }
            ?? historyItems.first
        let selectedID = visibleSelectedItem?.id

        VStack(alignment: .leading, spacing: AssistDesignTokens.ModuleIsland.toolbarSpacing) {
            ClipboardModuleToolbar(
                viewModel: viewModel,
                selectedFilter: $selectedFilter,
                selectedItem: visibleSelectedItem
            )

            if let issue = viewModel.captureIssue {
                CaptureIssuePanel(issue: issue, viewModel: viewModel)
            } else if !historyItems.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(
                            alignment: .top,
                            spacing: HistoryShelfTokens.cardSpacing
                        ) {
                            ForEach(historyItems) { item in
                                Group {
                                    switch item {
                                    case let .screenshot(capture):
                                        CaptureGalleryCard(
                                            item: capture,
                                            thumbnail: viewModel.thumbnail(for: capture),
                                            contextPreview: viewModel.contextPreview(for: capture),
                                            canCopyContext: viewModel.canCopyContextMarkdown(capture),
                                            isSelected: item.id == selectedID,
                                            onDragChanged: onDragChanged
                                        ) {
                                            viewModel.copyImageItem(capture)
                                        } copyContextAction: {
                                            viewModel.copyContextMarkdown(capture)
                                        } deleteAction: {
                                            viewModel.delete(item)
                                        }
                                    case let .text(textClip):
                                        TextClipGalleryCard(
                                            item: textClip,
                                            isSelected: item.id == selectedID,
                                            onDragChanged: onDragChanged
                                        ) {
                                            viewModel.copyTextItem(textClip)
                                        } deleteAction: {
                                            viewModel.delete(item)
                                        }
                                    }
                                }
                                .frame(
                                    width: HistoryShelfTokens.cardSize,
                                    height: HistoryShelfTokens.cardSize,
                                    alignment: .top
                                )
                                .id(item.id)
                            }
                        }
                    }
                    .frame(height: HistoryShelfTokens.cardSize, alignment: .top)
                    .onAppear {
                        alignGalleryToLeadingEdge(
                            proxy,
                            firstItemID: historyItems.first?.id
                        )
                    }
                    .onChange(of: historyItems.first?.id) { _, firstItemID in
                        alignGalleryToLeadingEdge(proxy, firstItemID: firstItemID)
                    }
                }
            } else {
                IslandHistoryEmptyState(
                    filter: selectedFilter,
                    showsDebugActions: viewModel.historyItems.isEmpty,
                    viewModel: viewModel
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func alignGalleryToLeadingEdge(
        _ proxy: ScrollViewProxy,
        firstItemID: ClipboardHistoryItem.ID?
    ) {
        guard let firstItemID else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            proxy.scrollTo(firstItemID, anchor: .leading)
        }
    }
}

private struct ClipboardModuleToolbar: View {
    @ObservedObject var viewModel: PillViewModel
    @Binding var selectedFilter: ClipboardHistoryFilter
    let selectedItem: ClipboardHistoryItem?

    private let actionSize = AssistDesignTokens.Control.compactHeight

    var body: some View {
        IslandModuleToolbar {
            if viewModel.captureIssue == nil {
                HStack(spacing: AssistDesignTokens.Spacing.xxSmall) {
                    ForEach(ClipboardHistoryFilter.allCases) { filter in
                        IslandChip(
                            title: filter.title,
                            isSelected: filter == selectedFilter,
                            accessibilityLabel: "Show \(filter.title.lowercased())"
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
            } else {
                Text("Needs attention")
                    .font(AssistDesignTokens.Typography.headline)
                    .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.strong))
            }
        } trailing: {
            if case let .screenshot(capture) = selectedItem {
                HStack(spacing: AssistDesignTokens.Spacing.xxSmall) {
                    if viewModel.showsCopyContext(for: capture) {
                        IslandIconButton(
                            icon: .copy,
                            tooltip: viewModel.canCopyContext(for: capture)
                                ? "Copy saved Markdown context and screenshot"
                                : "Context is still transcribing",
                            isEnabled: viewModel.canCopyContext(for: capture),
                            size: actionSize
                        ) {
                            viewModel.selectScreenshot(capture)
                            viewModel.copyLatestContext()
                        }
                    }

                    IslandIconButton(icon: .image, tooltip: "Copy selected screenshot image", size: actionSize) {
                        viewModel.copyImageItem(capture)
                    }

                    IslandIconButton(icon: .folder, tooltip: "Reveal selected screenshot in Finder", size: actionSize) {
                        viewModel.revealScreenshotInFinder(capture)
                    }
                }
            }
        }
        .foregroundStyle(.white)
    }
}

private struct IslandHistoryEmptyState: View {
    let filter: ClipboardHistoryFilter
    let showsDebugActions: Bool
    @ObservedObject var viewModel: PillViewModel

    private var message: String {
        switch filter {
        case .all:
            CaptureShortcut.emptyHistoryHint
        case .text:
            "Copied text will appear here"
        case .images:
            "Captured screenshots will appear here"
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: AssistDesignTokens.Spacing.small) {
            HugeIcon(
                filter.emptyIcon,
                size: 20,
                color: .white.opacity(AssistDesignTokens.Opacity.subtle)
            )
            .padding(.bottom, AssistDesignTokens.Spacing.xxxSmall)

            Text(filter.emptyTitle)
                .font(AssistDesignTokens.Typography.headline)
                .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.primary))

            Text(message)
                .font(AssistDesignTokens.Typography.footnote(.medium))
                .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.muted))
                .fixedSize(horizontal: false, vertical: true)

            if showsDebugActions {
                DebugActionsView(viewModel: viewModel)
                    .padding(.top, AssistDesignTokens.Spacing.xxSmall)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
    }
}

private struct CaptureIssuePanel: View {
    let issue: CaptureIssue
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.26, blue: 0.16).opacity(0.18))
                    .frame(width: 38, height: 38)

                HugeIcon(.info, size: 16, color: Color(red: 1.0, green: 0.38, blue: 0.16))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(issue.title)
                    .font(AssistDesignTokens.Typography.headline)
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)

                Text(issue.message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = issue.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(.white.opacity(0.44))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    CaptureIssueActionButton(title: issue.primaryActionTitle, isPrimary: true) {
                        viewModel.perform(issue.primaryAction)
                    }

                    if let secondaryActionTitle = issue.secondaryActionTitle,
                       let secondaryAction = issue.secondaryAction {
                        CaptureIssueActionButton(title: secondaryActionTitle, isPrimary: false) {
                            viewModel.perform(secondaryAction)
                        }
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.32, blue: 0.14).opacity(0.36), lineWidth: 1)
        }
    }
}

private struct CaptureIssueActionButton: View {
    let title: String
    let isPrimary: Bool

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(
                    isPrimary ? AssistDesignTokens.Mono.selectedForeground : Color.white.opacity(0.9)
                )
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    isPrimary ? AssistDesignTokens.Mono.selectedFill : Color.white.opacity(0.12),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

private struct DebugActionsView: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                DebugActionButton(title: "Test Screenshot", icon: .camera, tooltip: "Run a screenshot capture test") {
                    viewModel.testScreenshot()
                }

                DebugActionButton(title: "Test Overlay", icon: .pen, tooltip: "Run an annotation overlay test") {
                    viewModel.testOverlay()
                }
            }

            if let diagnosticMessage = viewModel.diagnosticMessage {
                Text(diagnosticMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }
        }
    }
}

private struct DebugActionButton: View {
    let title: String
    let icon: HugeIconKind
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                HugeIcon(icon, size: 12, color: .white.opacity(0.88))
                Text(title)
                    .font(AssistDesignTokens.Typography.footnote(.medium))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

enum HistoryCardActionVisibility {
    static func isVisible(
        cardHovered: Bool,
        deleteActionHovered: Bool,
        contextActionHovered: Bool
    ) -> Bool {
        cardHovered || deleteActionHovered || contextActionHovered
    }
}

private struct CaptureGalleryCard: View {
    let item: CaptureItem
    let thumbnail: NSImage?
    let contextPreview: String
    let canCopyContext: Bool
    let isSelected: Bool
    let onDragChanged: (Bool) -> Void
    let action: () -> Void
    let copyContextAction: () -> Void
    let deleteAction: () -> Void
    @State private var isHovered = false
    @State private var isDeleteHovered = false
    @State private var isContextCopyHovered = false

    private var isActionTrayVisible: Bool {
        HistoryCardActionVisibility.isVisible(
            cardHovered: isHovered,
            deleteActionHovered: isDeleteHovered,
            contextActionHovered: isContextCopyHovered
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            IslandDraggableCard(
                pasteboardWriter: { item.dragPasteboardWriter },
                dragImage: {
                    IslandDragPreview.screenshot(
                        thumbnail: thumbnail,
                        imagePath: item.imagePath
                    )
                },
                onClick: action,
                onDragChanged: onDragChanged
            ) {
                cardPreview
            }
            .help("Click card to copy screenshot")
            .accessibilityLabel(
                item.hasVoiceContext
                    ? "Capture with voice context. \(contextPreview)"
                    : "Screenshot"
            )
            .accessibilityAddTraits(.isButton)

            HStack(spacing: 0) {
                DeleteCardButton(
                    isVisible: isActionTrayVisible,
                    isHovered: $isDeleteHovered,
                    action: deleteAction
                )

                if item.hasVoiceContext {
                    CaptureContextCopyButton(
                        isEnabled: canCopyContext,
                        isHovered: $isContextCopyHovered,
                        action: copyContextAction
                    )
                }
            }
            .padding(AssistDesignTokens.Spacing.xxxSmall)
            .background(
                AssistDesignTokens.Palette.paper.opacity(
                    isActionTrayVisible ? 1 : 0
                ),
                in: Capsule()
            )
            .padding(AssistDesignTokens.Spacing.xxSmall)
            .opacity(isActionTrayVisible ? 1 : 0)
            .allowsHitTesting(isActionTrayVisible)
            .accessibilityHidden(!isActionTrayVisible)
            .animation(AssistDesignTokens.Motion.quick, value: isActionTrayVisible)
        }
        .frame(
            width: HistoryShelfTokens.cardSize,
            height: HistoryShelfTokens.cardSize
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var cardPreview: some View {
        if item.hasVoiceContext {
            let tint = AssistDesignTokens.IslandCard.contextTint
            ZStack(alignment: .topLeading) {
                IslandCardSurface(tint: tint)
                    .frame(width: 58, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.small, style: .continuous))

                VStack(spacing: 0) {
                    screenshotThumbnail(height: 84)

                    HStack(alignment: .top, spacing: AssistDesignTokens.Spacing.xSmall) {
                        HugeIcon(
                            .document,
                            size: 11,
                            color: tint.secondaryInk
                        )
                        .padding(.top, 1)

                        VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.xxxSmall) {
                            Text("context.md")
                                .font(AssistDesignTokens.Typography.micro(.semibold))
                                .foregroundStyle(tint.secondaryInk)

                            Text(contextPreview)
                                .font(AssistDesignTokens.Typography.micro(.medium))
                                .foregroundStyle(tint.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, AssistDesignTokens.Spacing.xSmall)
                    .frame(
                        width: HistoryShelfTokens.cardSize,
                        height: 50,
                        alignment: .topLeading
                    )
                }
                .frame(
                    width: HistoryShelfTokens.cardSize,
                    height: HistoryShelfTokens.cardSize - AssistDesignTokens.Spacing.small,
                    alignment: .top
                )
                .background(IslandCardSurface(tint: tint))
                .clipShape(RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium, style: .continuous))
                .overlay { IslandSelectionRing(isSelected: isSelected) }
                .offset(y: AssistDesignTokens.Spacing.small)
            }
            .frame(
                width: HistoryShelfTokens.cardSize,
                height: HistoryShelfTokens.cardSize,
                alignment: .topLeading
            )
        } else {
            screenshotThumbnail(height: HistoryShelfTokens.cardSize)
                .clipShape(RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium, style: .continuous))
                .overlay { IslandSelectionRing(isSelected: isSelected) }
        }
    }

    private func screenshotThumbnail(height: CGFloat) -> some View {
        ZStack {
            AssistDesignTokens.Palette.elevatedInk

            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: HistoryShelfTokens.cardSize, height: height)
                    .clipped()
            } else {
                HugeIcon(
                    .image,
                    size: 24,
                    color: .white.opacity(AssistDesignTokens.Opacity.muted)
                )
                .help("Screenshot thumbnail")
            }
        }
        .frame(width: HistoryShelfTokens.cardSize, height: height)
    }

}

private struct CaptureContextCopyButton: View {
    let isEnabled: Bool
    @Binding var isHovered: Bool
    let action: () -> Void

    private var tooltip: String {
        isEnabled ? "Copy context.md" : "context.md is not ready to copy"
    }

    var body: some View {
        ZStack {
            Color.clear
                .frame(
                    width: HistoryShelfTokens.actionHitArea,
                    height: HistoryShelfTokens.actionHitArea
                )
                .contentShape(Rectangle())

            Button(action: action) {
                HugeIcon(
                    .copy,
                    size: 12,
                    color: isEnabled
                        ? AssistDesignTokens.Palette.ink.opacity(
                            isHovered
                                ? AssistDesignTokens.Opacity.primary
                                : AssistDesignTokens.Opacity.strong
                        )
                        : AssistDesignTokens.Palette.zinc.opacity(AssistDesignTokens.Opacity.disabled)
                )
                .frame(
                    width: HistoryShelfTokens.actionControl,
                    height: HistoryShelfTokens.actionControl
                )
                .background(
                    isEnabled && isHovered
                        ? AssistDesignTokens.Palette.softPaper
                        : .clear,
                    in: RoundedRectangle(
                        cornerRadius: AssistDesignTokens.Radius.control,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .help(tooltip)
            .accessibilityLabel(tooltip)
        }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct TextClipGalleryCard: View {
    let item: TextClipItem
    let isSelected: Bool
    let onDragChanged: (Bool) -> Void
    let action: () -> Void
    let deleteAction: () -> Void
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    private var isDeleteVisible: Bool {
        isHovered || isDeleteHovered
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            IslandDraggableCard(
                pasteboardWriter: { item.dragPasteboardWriter },
                dragImage: { IslandDragPreview.text(item) },
                onClick: action,
                onDragChanged: onDragChanged
            ) {
                textPreview
                .overlay { IslandSelectionRing(isSelected: isSelected) }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AssistDesignTokens.Radius.medium,
                        style: .continuous
                    )
                )
            }
            .help("Click card to copy text")
            .accessibilityLabel(
                item.colorCode.map { "Color \($0.displayValue)" } ?? "Text clip"
            )
            .accessibilityAddTraits(.isButton)

            DeleteCardButton(isVisible: isDeleteVisible, isHovered: $isDeleteHovered, action: deleteAction)
                .padding(AssistDesignTokens.Spacing.xxxSmall)
                .background(AssistDesignTokens.Palette.paper, in: Capsule())
                .padding(AssistDesignTokens.Spacing.xxSmall)
                .opacity(isDeleteVisible ? 1 : 0)
        }
        .frame(
            width: HistoryShelfTokens.cardSize,
            height: HistoryShelfTokens.cardSize
        )
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var textPreview: some View {
        if let colorCode = item.colorCode {
            ZStack(alignment: .bottomLeading) {
                Color(clipboardColor: colorCode)

                Text(colorCode.displayValue)
                    .font(AssistDesignTokens.Typography.mono)
                    .foregroundStyle(
                        colorCode.usesDarkForeground(
                            over: AssistDesignTokens.Palette.inkComponents
                        )
                            ? AssistDesignTokens.Palette.ink
                            : AssistDesignTokens.Palette.paper
                    )
                    .padding(AssistDesignTokens.Spacing.large)
            }
            .frame(
                width: HistoryShelfTokens.cardSize,
                height: HistoryShelfTokens.cardSize
            )
        } else {
            VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.xSmall) {
                Text(item.preview)
                    .font(AssistDesignTokens.Typography.footnote(.medium))
                    .foregroundStyle(tint.ink)
                    .lineLimit(7)
            }
            .padding(AssistDesignTokens.Spacing.large)
            .frame(
                width: HistoryShelfTokens.cardSize,
                height: HistoryShelfTokens.cardSize,
                alignment: .topLeading
            )
            .background(IslandCardSurface(tint: tint))
        }
    }

    private var tint: AssistDesignTokens.IslandCard.Tint {
        AssistDesignTokens.IslandCard.textTint(for: item.id)
    }
}

/// Marks the selected island card with a light ring and a dark inner ring,
/// so one of them stands out over any thumbnail, tint, or color clip.
private struct IslandSelectionRing: View {
    let isSelected: Bool

    var body: some View {
        if isSelected {
            let shape = RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium, style: .continuous)
            ZStack {
                shape.strokeBorder(
                    HistoryShelfTokens.selectionRingOuter,
                    lineWidth: HistoryShelfTokens.selectionRingWidth
                )
                shape
                    .inset(by: HistoryShelfTokens.selectionRingWidth)
                    .strokeBorder(
                        HistoryShelfTokens.selectionRingInner,
                        lineWidth: HistoryShelfTokens.selectionRingInnerWidth
                    )
            }
            .allowsHitTesting(false)
        }
    }
}

@MainActor
private enum IslandDragPreview {
    static let cardSize = NSSize(
        width: HistoryShelfTokens.cardSize,
        height: HistoryShelfTokens.cardSize
    )
    static let cornerRadius: CGFloat = 10

    static func screenshot(thumbnail: NSImage?, imagePath: String) -> NSImage {
        let sourceImage = thumbnail ?? NSImage(contentsOfFile: imagePath)
        return cardImage { rect in
            guard let sourceImage else {
                drawPlaceholder(in: rect, title: "Image")
                return
            }

            sourceImage.draw(
                in: aspectFillRect(for: sourceImage.size, in: rect),
                from: .zero,
                operation: .copy,
                fraction: 1
            )
        }
    }

    static func text(_ item: TextClipItem) -> NSImage {
        let tint = AssistDesignTokens.IslandCard.textTint(for: item.id)
        return cardImage { rect in
            if let colorCode = item.colorCode {
                NSColor(
                    calibratedRed: colorCode.red,
                    green: colorCode.green,
                    blue: colorCode.blue,
                    alpha: colorCode.alpha
                ).setFill()
                rect.fill()
            } else {
                IslandCardTexture.draw(tint, in: rect)
            }

            let insetRect = rect.insetBy(dx: 12, dy: 12)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail

            let foreground: NSColor = if let colorCode = item.colorCode {
                colorCode.usesDarkForeground(over: AssistDesignTokens.Palette.inkComponents)
                    ? NSColor.black.withAlphaComponent(0.9)
                    : NSColor.white.withAlphaComponent(0.9)
            } else {
                NSColor(tint.ink)
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: foreground,
                .paragraphStyle: paragraphStyle
            ]

            NSString(string: item.colorCode?.displayValue ?? item.preview).draw(
                with: insetRect,
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: attributes
            )
        }
    }

    private static func cardImage(drawContent: (NSRect) -> Void) -> NSImage {
        let image = NSImage(size: cardSize)
        let rect = NSRect(origin: .zero, size: cardSize)

        image.lockFocus()
        let cardPath = NSBezierPath(
            roundedRect: rect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
        cardPath.fill()
        NSGraphicsContext.current?.saveGraphicsState()
        cardPath.addClip()
        drawContent(rect)
        NSGraphicsContext.current?.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.28).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()
        image.unlockFocus()

        return image
    }

    private static func aspectFillRect(for imageSize: NSSize, in rect: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }

        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func drawPlaceholder(in rect: NSRect, title: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.58)
        ]
        let textSize = NSString(string: title).size(withAttributes: attributes)
        let textRect = NSRect(
            x: rect.midX - textSize.width / 2,
            y: rect.midY - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )

        NSString(string: title).draw(in: textRect, withAttributes: attributes)
    }
}

private struct DeleteCardButton: View {
    let isVisible: Bool
    @Binding var isHovered: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .frame(
                    width: HistoryShelfTokens.actionHitArea,
                    height: HistoryShelfTokens.actionHitArea
                )
                .contentShape(Rectangle())

            Button(action: action) {
                HugeIcon(
                    .trash,
                    size: 12,
                    color: AssistDesignTokens.Palette.danger.opacity(
                        isHovered ? 1 : AssistDesignTokens.Opacity.primary
                    )
                )
                    .frame(
                        width: HistoryShelfTokens.actionControl,
                        height: HistoryShelfTokens.actionControl
                    )
                    .background(
                        AssistDesignTokens.Palette.danger.opacity(
                            isHovered ? AssistDesignTokens.Opacity.destructiveHoverSurface : 0
                        ),
                        in: RoundedRectangle(
                            cornerRadius: AssistDesignTokens.Radius.control,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.plain)
            .help("Delete item")
            .accessibilityLabel("Delete item")
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.92)
        }
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isVisible)
    }
}
