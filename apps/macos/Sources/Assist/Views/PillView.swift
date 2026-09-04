import AppKit
import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var settings: PillSettings
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
        PillChromeMetrics.expandedSize(settings: settings)
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
                    CollapsedIslandHeader(viewModel: viewModel)
                        .frame(
                            width: collapsedSize.width,
                            height: collapsedSize.height
                        )
                        .transition(.opacity.animation(.easeOut(duration: 0.08)))
                }

                if viewModel.isExpandedContentVisible {
                    ExpandedIslandView(
                        viewModel: viewModel,
                        onDragChanged: onIslandDragChanged
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }
}

// The idle island is deliberately quiet. Short-lived feedback is text-led and
// anchored to the leading edge; navigation and branding live in expanded UI.
private struct CollapsedIslandHeader: View {
    @ObservedObject var viewModel: PillViewModel

    private var feedbackAnimation: Animation {
        AssistDesignTokens.Motion.feedback
    }

    var body: some View {
        HStack(spacing: 0) {
            if let feedback = viewModel.copyFeedback {
                Text(feedback.badge)
                    .font(AssistFont.roundedFootnote(.semibold))
                    .foregroundStyle(feedbackForeground(for: feedback.kind))
                    .lineLimit(1)
                    .opacity(viewModel.isCopyFeedbackVisible ? 1 : 0)
                    .transition(.opacity)
                    .help("\(feedback.badge): \(feedback.preview)")
                    .accessibilityLabel("\(feedback.badge). \(feedback.preview)")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AssistDesignTokens.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(feedbackAnimation, value: viewModel.copyFeedback)
        .animation(feedbackAnimation, value: viewModel.isCopyFeedbackVisible)
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

struct ExpandedIslandView: View {
    @ObservedObject var viewModel: PillViewModel
    let onDragChanged: (Bool) -> Void
    @State private var selectedFilter: ClipboardHistoryFilter = .all
    private static let galleryLeadingAnchorID = "gallery-leading-anchor"
    private static let galleryClipInset: CGFloat = 2
    private static let galleryViewportHeight: CGFloat = 144

    var body: some View {
        let filteredItems = viewModel.historyItems.filter(selectedFilter.includes)
        let historyItems = Array(filteredItems.prefix(24))
        let visibleSelectedItem = historyItems.first { $0.id == viewModel.selectedItem?.id }
            ?? historyItems.first
        let selectedID = visibleSelectedItem?.id

        VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.medium) {
            ExpandedIslandHeader(
                viewModel: viewModel,
                selectedFilter: $selectedFilter,
                selectedItem: visibleSelectedItem
            )
                .frame(height: AssistDesignTokens.Control.regularHeight)
                .zIndex(1)

            if let issue = viewModel.captureIssue {
                CaptureIssuePanel(issue: issue, viewModel: viewModel)
            } else if !historyItems.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: 0, height: 1)
                                .id(Self.galleryLeadingAnchorID)
                                .accessibilityHidden(true)

                            LazyHStack(spacing: AssistDesignTokens.Spacing.large) {
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
                                    .id(item.id)
                                }
                            }
                            .padding(.horizontal, Self.galleryClipInset)
                        }
                        .padding(.vertical, 1)
                    }
                    .frame(height: Self.galleryViewportHeight, alignment: .top)
                    .onAppear {
                        alignGalleryToLeadingEdge(proxy)
                    }
                    .onChange(of: historyItems.first?.id) { _, firstItemID in
                        guard firstItemID != nil else { return }
                        alignGalleryToLeadingEdge(proxy)
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
        .padding(.horizontal, AssistDesignTokens.Spacing.shelfInset)
        .padding(.top, AssistDesignTokens.Spacing.xSmall)
        .padding(.bottom, AssistDesignTokens.Spacing.xLarge)
    }

    private func alignGalleryToLeadingEdge(_ proxy: ScrollViewProxy) {
        func align() {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                proxy.scrollTo(Self.galleryLeadingAnchorID, anchor: .leading)
            }
        }

        align()
        DispatchQueue.main.async(execute: align)
    }
}

private struct ExpandedIslandHeader: View {
    @ObservedObject var viewModel: PillViewModel
    @Binding var selectedFilter: ClipboardHistoryFilter
    let selectedItem: ClipboardHistoryItem?

    var body: some View {
        HStack(spacing: AssistDesignTokens.Spacing.medium) {
            if viewModel.captureIssue == nil {
                HStack(spacing: AssistDesignTokens.Spacing.xxSmall) {
                    ForEach(ClipboardHistoryFilter.allCases) { filter in
                        IslandHistoryFilterChip(
                            filter: filter,
                            selectedFilter: $selectedFilter
                        )
                    }
                }
            } else {
                Text("Needs attention")
                    .font(AssistFont.roundedHeadline())
                    .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.strong))
            }

            Spacer()

            IslandIconButton(icon: .grid, tooltip: "Open Assist") {
                viewModel.openControls()
            }

            if case let .screenshot(capture) = selectedItem {
                if viewModel.showsCopyContext(for: capture) {
                    IslandIconButton(
                        icon: .copy,
                        tooltip: viewModel.canCopyContext(for: capture)
                            ? "Copy saved Markdown context and screenshot"
                            : "Context is still transcribing",
                        isEnabled: viewModel.canCopyContext(for: capture)
                    ) {
                        viewModel.selectScreenshot(capture)
                        viewModel.copyLatestContext()
                    }
                }

                IslandIconButton(icon: .image, tooltip: "Copy selected screenshot image") {
                    viewModel.copyImageItem(capture)
                }

                IslandIconButton(icon: .folder, tooltip: "Reveal selected screenshot in Finder") {
                    viewModel.revealScreenshotInFinder(capture)
                }
            }
        }
        .foregroundStyle(.white)
    }
}

private struct IslandHistoryFilterChip: View {
    let filter: ClipboardHistoryFilter
    @Binding var selectedFilter: ClipboardHistoryFilter

    private var isSelected: Bool {
        filter == selectedFilter
    }

    var body: some View {
        Button {
            selectedFilter = filter
        } label: {
            Text(filter.title)
                .font(AssistFont.roundedFootnote(isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? AssistDesignTokens.Palette.ink
                        : AssistDesignTokens.Palette.paper.opacity(AssistDesignTokens.Opacity.secondary)
                )
                .lineLimit(1)
                .padding(.horizontal, AssistDesignTokens.Spacing.medium)
                .frame(height: AssistDesignTokens.Control.compactHeight)
                .background(
                    isSelected ? AssistDesignTokens.Palette.paper : .clear,
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .accessibilityLabel("Show \(filter.title.lowercased())")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .animation(AssistDesignTokens.Motion.quick, value: isSelected)
    }
}

private struct IslandHistoryEmptyState: View {
    let filter: ClipboardHistoryFilter
    let showsDebugActions: Bool
    @ObservedObject var viewModel: PillViewModel

    private var icon: HugeIconKind {
        switch filter {
        case .all:
            .camera
        case .images:
            .image
        case .text:
            .document
        }
    }

    private var title: String {
        switch filter {
        case .all:
            "No captures yet"
        case .text:
            "No text yet"
        case .images:
            "No images yet"
        }
    }

    private var message: String {
        switch filter {
        case .all:
            "Hold ⌥ to annotate  ·  ⌃⌥ for a clean screenshot"
        case .text:
            "Copied text will appear here"
        case .images:
            "Captured screenshots will appear here"
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: AssistDesignTokens.Spacing.small) {
            HugeIcon(
                icon,
                size: 20,
                color: .white.opacity(AssistDesignTokens.Opacity.subtle)
            )
            .padding(.bottom, AssistDesignTokens.Spacing.xxxSmall)

            Text(title)
                .font(AssistFont.roundedHeadline())
                .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.primary))

            Text(message)
                .font(AssistFont.roundedFootnote(.medium))
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
                    .font(AssistFont.roundedHeadline())
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
                .foregroundStyle(isPrimary ? Color.black : Color.white.opacity(0.9))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    isPrimary ? Color.white : Color.white.opacity(0.12),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

private struct IslandIconButton: View {
    let icon: HugeIconKind
    let tooltip: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HugeIcon(
                icon,
                size: AssistDesignTokens.Icon.regular,
                color: .white.opacity(
                    isEnabled
                        ? (isHovered ? AssistDesignTokens.Opacity.primary : AssistDesignTokens.Opacity.secondary)
                        : AssistDesignTokens.Opacity.disabled
                )
            )
                .frame(
                    width: AssistDesignTokens.Control.iconButton,
                    height: AssistDesignTokens.Control.iconButton
                )
                .background(
                    Color.white.opacity(
                        isEnabled && isHovered ? AssistDesignTokens.Opacity.hoverSurface : 0
                    ),
                    in: RoundedRectangle(
                        cornerRadius: AssistDesignTokens.Radius.control,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(tooltip)
        .pointingHandCursor(isEnabled: isEnabled)
        .overlay(alignment: .bottomTrailing) {
            if isHovered {
                Text(tooltip)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AssistDesignTokens.Palette.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, AssistDesignTokens.Spacing.small)
                    .frame(height: AssistDesignTokens.Control.tooltipHeight)
                    .background(AssistDesignTokens.Palette.paper, in: Capsule())
                    .offset(y: AssistDesignTokens.Spacing.xxxLarge + AssistDesignTokens.Spacing.xxxSmall)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    .allowsHitTesting(false)
            }
        }
        .zIndex(isHovered ? 20 : 0)
        .onHover { isHovered = $0 }
        .animation(AssistDesignTokens.Motion.quick, value: isHovered)
    }

    @State private var isHovered = false
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
                    .font(AssistFont.roundedFootnote(.medium))
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

    private var isDeleteVisible: Bool {
        isHovered || isDeleteHovered
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
                    isVisible: isDeleteVisible,
                    isHovered: $isDeleteHovered,
                    action: deleteAction
                )

                if item.hasVoiceContext {
                    CaptureContextCopyButton(
                        isEnabled: canCopyContext,
                        action: copyContextAction
                    )
                }
            }
            .padding(AssistDesignTokens.Spacing.xxxSmall)
            .background(
                AssistDesignTokens.Palette.paper.opacity(
                    item.hasVoiceContext || isDeleteVisible ? 1 : 0
                ),
                in: Capsule()
            )
            .padding(AssistDesignTokens.Spacing.xxSmall)
            .animation(AssistDesignTokens.Motion.quick, value: isDeleteVisible)
        }
        .frame(width: 142, height: 142)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var cardPreview: some View {
        if item.hasVoiceContext {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.small, style: .continuous)
                    .fill(AssistDesignTokens.Palette.folder)
                    .frame(width: 58, height: 18)

                VStack(spacing: 0) {
                    screenshotThumbnail(height: 84)

                    HStack(alignment: .top, spacing: AssistDesignTokens.Spacing.xSmall) {
                        HugeIcon(
                            .document,
                            size: 11,
                            color: .white.opacity(AssistDesignTokens.Opacity.muted)
                        )
                        .padding(.top, 1)

                        VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.xxxSmall) {
                            Text("context.md")
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.muted))

                            Text(contextPreview)
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.strong))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, AssistDesignTokens.Spacing.xSmall)
                    .frame(width: 142, height: 50, alignment: .topLeading)
                    .background(AssistDesignTokens.Palette.ink.opacity(0.26))
                }
                .frame(width: 142, height: 134, alignment: .top)
                .background(AssistDesignTokens.Palette.folder)
                .clipShape(RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium, style: .continuous))
                .overlay { selectionStroke }
                .offset(y: AssistDesignTokens.Spacing.small)
            }
            .frame(width: 142, height: 142, alignment: .topLeading)
        } else {
            screenshotThumbnail(height: 142)
                .clipShape(RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium, style: .continuous))
                .overlay { selectionStroke }
        }
    }

    private func screenshotThumbnail(height: CGFloat) -> some View {
        ZStack {
            AssistDesignTokens.Palette.elevatedInk

            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 142, height: height)
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
        .frame(width: 142, height: height)
    }

    private var selectionStroke: some View {
        RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium, style: .continuous)
            .stroke(
                isSelected
                    ? AssistDesignTokens.Palette.paper.opacity(AssistDesignTokens.Opacity.selectedStroke)
                    : .clear,
                lineWidth: 1
            )
    }
}

private struct CaptureContextCopyButton: View {
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var tooltip: String {
        isEnabled ? "Copy context.md" : "context.md is not ready to copy"
    }

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 32, height: 32)
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
                .frame(width: 24, height: 24)
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
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selectionColor, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var textPreview: some View {
        if let colorCode = item.colorCode {
            ZStack(alignment: .bottomLeading) {
                Color(clipboardColor: colorCode)

                Text(colorCode.displayValue)
                    .font(AssistFont.mono())
                    .foregroundStyle(
                        colorCode.usesDarkForeground
                            ? AssistDesignTokens.Palette.ink
                            : AssistDesignTokens.Palette.paper
                    )
                    .padding(AssistDesignTokens.Spacing.large)
            }
            .frame(width: 142, height: 142)
        } else {
            VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.xSmall) {
                Text(item.preview)
                    .font(AssistFont.roundedFootnote(.medium))
                    .foregroundStyle(.white.opacity(AssistDesignTokens.Opacity.strong))
                    .lineLimit(7)
            }
            .padding(AssistDesignTokens.Spacing.large)
            .frame(width: 142, height: 142, alignment: .topLeading)
            .background(
                Color.white.opacity(
                    isSelected
                        ? AssistDesignTokens.Opacity.hoverSurface
                        : AssistDesignTokens.Opacity.quietSurface
                ),
                in: RoundedRectangle(cornerRadius: AssistDesignTokens.Radius.medium, style: .continuous)
            )
        }
    }

    private var selectionColor: Color {
        guard isSelected else { return .clear }
        guard let colorCode = item.colorCode else {
            return AssistDesignTokens.Palette.paper.opacity(AssistDesignTokens.Opacity.selectedStroke)
        }

        return (colorCode.usesDarkForeground
            ? AssistDesignTokens.Palette.ink
            : AssistDesignTokens.Palette.paper
        ).opacity(AssistDesignTokens.Opacity.selectedStroke)
    }
}

private struct IslandDraggableCard<Content: View>: View {
    let pasteboardWriter: () -> (any NSPasteboardWriting)?
    let dragImage: () -> NSImage?
    let onClick: () -> Void
    let onDragChanged: (Bool) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        content
            .overlay {
                IslandDragSourceOverlay(
                    pasteboardWriter: pasteboardWriter,
                    dragImage: dragImage,
                    onClick: onClick,
                    onDragChanged: onDragChanged
                )
            }
            .accessibilityAction {
                onClick()
            }
    }
}

private struct IslandDragSourceOverlay: NSViewRepresentable {
    let pasteboardWriter: () -> (any NSPasteboardWriting)?
    let dragImage: () -> NSImage?
    let onClick: () -> Void
    let onDragChanged: (Bool) -> Void

    func makeNSView(context: Context) -> IslandDragSourceView {
        let view = IslandDragSourceView()
        view.pasteboardWriter = pasteboardWriter
        view.dragImage = dragImage
        view.onClick = onClick
        view.onDragChanged = onDragChanged
        return view
    }

    func updateNSView(_ view: IslandDragSourceView, context: Context) {
        view.pasteboardWriter = pasteboardWriter
        view.dragImage = dragImage
        view.onClick = onClick
        view.onDragChanged = onDragChanged
    }
}

private final class IslandDragSourceView: NSView, NSDraggingSource {
    var pasteboardWriter: (() -> (any NSPasteboardWriting)?)?
    var dragImage: (() -> NSImage?)?
    var onClick: (() -> Void)?
    var onDragChanged: ((Bool) -> Void)?

    private var mouseDownEvent: NSEvent?
    private var mouseDownPoint = NSPoint.zero
    private var hasStartedDrag = false

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        hasStartedDrag = false
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag,
              dragDistance(from: mouseDownPoint, to: convert(event.locationInWindow, from: nil)) >= 3,
              let writer = pasteboardWriter?() else { return }

        hasStartedDrag = true
        onDragChanged?(true)

        let draggingItem = NSDraggingItem(pasteboardWriter: writer)
        let previewImage = dragImage?() ?? fallbackDragImage()
        draggingItem.setDraggingFrame(draggingFrame(for: previewImage), contents: previewImage)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        if !hasStartedDrag {
            onClick?()
        }

        mouseDownEvent = nil
        setOpenHandIfPointerIsInside(localPoint: convert(event.locationInWindow, from: nil))
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        [.copy]
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        onDragChanged?(false)
        mouseDownEvent = nil
        hasStartedDrag = false
        setOpenHandIfPointerIsInside(screenPoint: screenPoint)
    }

    private func dragDistance(from start: NSPoint, to end: NSPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    private func setOpenHandIfPointerIsInside(screenPoint: NSPoint) {
        guard let window else { return }

        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        setOpenHandIfPointerIsInside(localPoint: convert(windowPoint, from: nil))
    }

    private func setOpenHandIfPointerIsInside(localPoint: NSPoint) {
        if bounds.contains(localPoint) {
            NSCursor.openHand.set()
        }
    }

    private func draggingFrame(for image: NSImage) -> NSRect {
        let size = image.size.width > 0 && image.size.height > 0 ? image.size : bounds.size

        return NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func fallbackDragImage() -> NSImage {
        let size = bounds.size.width > 0 && bounds.size.height > 0
            ? bounds.size
            : IslandDragPreview.cardSize

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.withAlphaComponent(0.16).setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: size),
            xRadius: IslandDragPreview.cornerRadius,
            yRadius: IslandDragPreview.cornerRadius
        ).fill()
        image.unlockFocus()
        return image
    }
}

private enum IslandDragPreview {
    static let cardSize = NSSize(width: 142, height: 142)
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
        cardImage { rect in
            if let colorCode = item.colorCode {
                NSColor(
                    calibratedRed: colorCode.red,
                    green: colorCode.green,
                    blue: colorCode.blue,
                    alpha: colorCode.alpha
                ).setFill()
                rect.fill()
            }

            let insetRect = rect.insetBy(dx: 12, dy: 12)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: item.colorCode?.usesDarkForeground == true
                    ? NSColor.black.withAlphaComponent(0.9)
                    : NSColor.white.withAlphaComponent(0.9),
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
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())

            Button(action: action) {
                HugeIcon(
                    .trash,
                    size: 12,
                    color: AssistDesignTokens.Palette.danger.opacity(
                        isHovered ? 1 : AssistDesignTokens.Opacity.primary
                    )
                )
                    .frame(width: 24, height: 24)
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
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isVisible)
    }
}
