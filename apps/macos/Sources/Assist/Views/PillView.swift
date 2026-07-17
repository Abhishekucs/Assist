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
        PillChromeMetrics.collapsedSize(
            settings: settings,
            showingCopyFeedback: viewModel.copyFeedback != nil
        )
    }

    private var expandedSize: CGSize {
        PillChromeMetrics.expandedSize(
            settings: settings,
            showingRateLimits: !visibleUsageLimitSnapshots.isEmpty
        )
    }

    private var chromeTopCornerRadius: CGFloat {
        PillChromeMetrics.topCornerRadius(forExpandedState: isIslandChromeVisible)
    }

    private var chromeBottomCornerRadius: CGFloat {
        PillChromeMetrics.bottomCornerRadius(forExpandedState: isIslandChromeVisible)
    }

    private var islandAnimation: Animation {
        .interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    }

    private var copyFeedbackAnimation: Animation {
        .spring(response: 0.52, dampingFraction: 0.96, blendDuration: 0.04)
    }

    private var shouldShowLoadingBorder: Bool {
        settings.showLoadingBorder && viewModel.isBusy
    }

    private var visibleUsageLimitSnapshots: [UsageLimitSnapshot] {
        viewModel.orderedUsageLimitSnapshots.filter { snapshot in
            switch snapshot.provider {
            case .claudeCode:
                settings.showClaudeCodeRateLimit
            case .codex:
                settings.showCodexRateLimit
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if viewModel.isCollapsedContentVisible {
                    CollapsedIslandHeader(
                        viewModel: viewModel,
                        usageLimitSnapshots: visibleUsageLimitSnapshots
                    )
                        .frame(
                            width: collapsedSize.width,
                            height: collapsedSize.height
                        )
                        .transition(.opacity.animation(.easeOut(duration: 0.08)))
                }

                if viewModel.isExpandedContentVisible {
                    ExpandedIslandView(
                        viewModel: viewModel,
                        usageLimitSnapshots: visibleUsageLimitSnapshots,
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
            .animation(copyFeedbackAnimation, value: viewModel.copyFeedback != nil)
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
        .onChange(of: viewModel.isExpanded) { _, isExpanded in
            if isExpanded {
                viewModel.refreshCodexTasksSoon()
            }
        }
    }
}

private struct CollapsedIslandHeader: View {
    @ObservedObject var viewModel: PillViewModel
    let usageLimitSnapshots: [UsageLimitSnapshot]

    private var copyFeedbackContentAnimation: Animation {
        .easeOut(duration: 0.18)
    }

    var body: some View {
        HStack(spacing: 8) {
            AssistLogo(size: 16)
                .help(AppIdentity.name)

            if let feedback = viewModel.copyFeedback {
                CopyFeedbackRow(feedback: feedback)
                    .opacity(viewModel.isCopyFeedbackVisible ? 1 : 0)
                    .scaleEffect(viewModel.isCopyFeedbackVisible ? 1 : 0.985)
                    .transition(
                        .opacity
                            .combined(with: .scale(scale: 0.96))
                            .animation(.easeOut(duration: 0.16))
                    )
            } else if !usageLimitSnapshots.isEmpty {
                UsageLimitCollapsedOverview(
                    snapshots: usageLimitSnapshots,
                    isRefreshing: viewModel.isRefreshingUsageLimits
                )
            } else {
                Text(viewModel.statusText)
                    .font(AssistFont.roundedFootnote(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .animation(.easeOut(duration: 0.16), value: viewModel.copyFeedback)
        .animation(copyFeedbackContentAnimation, value: viewModel.isCopyFeedbackVisible)
    }
}

private struct UsageLimitCollapsedOverview: View {
    let snapshots: [UsageLimitSnapshot]
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 7) {
            ForEach(snapshots) { snapshot in
                UsageLimitCompactChip(snapshot: snapshot)
            }

            if isRefreshing {
                Circle()
                    .fill(.white.opacity(0.42))
                    .frame(width: 4, height: 4)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct UsageLimitCompactChip: View {
    let snapshot: UsageLimitSnapshot

    var body: some View {
        HStack(spacing: 5) {
            UsageProviderLogo(provider: snapshot.provider, size: 14)

            Text(snapshot.provider.compactName)
                .foregroundStyle(.white.opacity(0.78))

            Text(snapshot.fiveHour.percentageText)
                .foregroundStyle(.white.opacity(snapshot.fiveHour.isAvailable ? 0.94 : 0.48))
        }
        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(Color.white.opacity(0.08), in: Capsule())
        .help("\(snapshot.provider.displayName) 5-hour usage")
        .accessibilityLabel("\(snapshot.provider.displayName) 5-hour usage \(snapshot.fiveHour.accessibilityText)")
    }
}

private struct CopyFeedbackRow: View {
    let feedback: CopyFeedback

    var body: some View {
        HStack(spacing: 10) {
            Text(feedback.preview)
                .font(AssistFont.roundedFootnote(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(feedback.badge)
                .font(AssistFont.roundedFootnote(.semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 19)
                .background(Color.white, in: Capsule())
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
    let usageLimitSnapshots: [UsageLimitSnapshot]
    let onDragChanged: (Bool) -> Void
    private static let galleryLeadingAnchorID = "gallery-leading-anchor"
    private static let galleryClipInset: CGFloat = 2

    var body: some View {
        let historyItems = Array(viewModel.historyItems.prefix(24))
        let selectedID = viewModel.selectedItem?.id

        VStack(alignment: .leading, spacing: 10) {
            CodexTaskStrip(viewModel: viewModel)
                .frame(height: 50)
                .zIndex(3)

            if !usageLimitSnapshots.isEmpty {
                UsageLimitDetailStrip(snapshots: usageLimitSnapshots)
                    .zIndex(2)
            }

            ExpandedIslandHeader(viewModel: viewModel)
                .frame(height: 34)
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

                            LazyHStack(spacing: 12) {
                                ForEach(historyItems) { item in
                                    Group {
                                        switch item {
                                        case let .screenshot(capture):
                                            CaptureGalleryCard(
                                                item: capture,
                                                thumbnail: viewModel.thumbnail(for: capture),
                                                isSelected: item.id == selectedID,
                                                onDragChanged: onDragChanged
                                            ) {
                                                viewModel.copyImageItem(capture)
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
                    .onAppear {
                        alignGalleryToLeadingEdge(proxy)
                    }
                    .onChange(of: historyItems.first?.id) { _, firstItemID in
                        guard firstItemID != nil else { return }
                        alignGalleryToLeadingEdge(proxy)
                    }
                }
            } else {
                VStack(alignment: .center, spacing: 10) {
                    Text("No items yet")
                        .font(.headline)

                    Text("Hold Option to annotate, press Control + Option for a clean screenshot, or copy text.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    DebugActionsView(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 6)
        .padding(.bottom, 14)
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

private struct CodexTaskStrip: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                UsageProviderLogo(provider: .codex, size: 16)

                Text("Codex")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 58, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 26)

            if viewModel.activeCodexTasks.isEmpty {
                HStack(spacing: 7) {
                    if viewModel.isRefreshingCodexTasks {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white.opacity(0.62))
                    }

                    Text(viewModel.isRefreshingCodexTasks ? "Checking active tasks…" : "No active Codex tasks")
                        .font(AssistFont.roundedFootnote(.medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(viewModel.activeCodexTasks.prefix(3)) { task in
                    CodexTaskCard(task: task) {
                        viewModel.openCodexTask(task)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct CodexTaskCard: View {
    let task: CodexTask
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(task.workspaceName)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: openAction) {
                HugeIcon(.arrowUpRight, size: 12, color: .white.opacity(isHovered ? 0.96 : 0.66))
                    .frame(width: 24, height: 24)
                    .background(
                        Color.white.opacity(isHovered ? 0.12 : 0),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .help("Open task in Codex")
            .accessibilityLabel("Open \(task.title) in Codex")
            .pointingHandCursor()
            .onHover { isHovered = $0 }
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, minHeight: 34)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @State private var isHovered = false
}

private struct UsageLimitDetailStrip: View {
    let snapshots: [UsageLimitSnapshot]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(snapshots) { snapshot in
                UsageLimitProviderPanel(snapshot: snapshot)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct UsageLimitProviderPanel: View {
    let snapshot: UsageLimitSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                UsageProviderLogo(provider: snapshot.provider, size: 16)

                Text(snapshot.provider.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer(minLength: 0)
            }

            UsageLimitWindowRow(
                title: "5h",
                window: snapshot.fiveHour,
                color: UsageLimitPalette.color(for: snapshot.provider)
            )

            UsageLimitWindowRow(
                title: "7d",
                window: snapshot.sevenDay,
                color: UsageLimitPalette.color(for: snapshot.provider)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct UsageLimitWindowRow: View {
    let title: String
    let window: UsageLimitWindow
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 18, alignment: .leading)

            UsageLimitProgressBar(window: window, color: color)
                .frame(height: 5)

            Text(window.percentageText)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(window.isAvailable ? 0.9 : 0.44))
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)

            Text(window.resetText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(window.isAvailable ? 0.56 : 0.42))
                .lineLimit(1)
                .frame(width: 62, alignment: .trailing)
        }
        .accessibilityLabel("\(title) \(window.accessibilityText)")
    }
}

private struct UsageLimitProgressBar: View {
    let window: UsageLimitWindow
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let progress = min(max((window.usedPercentage ?? 0) / 100, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))

                Capsule()
                    .fill(color.opacity(window.isAvailable ? 0.92 : 0))
                    .frame(width: proxy.size.width * progress)
            }
        }
    }
}

private struct ExpandedIslandHeader: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        HStack(spacing: 10) {
            Text(viewModel.captureIssue == nil ? "Recent items" : "Needs attention")
                .font(AssistFont.roundedHeadline())
                .foregroundStyle(.white.opacity(0.86))

            Spacer()

            IslandIconButton(icon: .grid, tooltip: "Open Assist") {
                viewModel.openControls()
            }

            if viewModel.canCopySelectedImage {
                IslandIconButton(icon: .image, tooltip: "Copy selected screenshot image") {
                    viewModel.copyLatestImage()
                }
            }

            if viewModel.canRevealSelectedScreenshot {
                IslandIconButton(icon: .folder, tooltip: "Reveal selected screenshot in Finder") {
                    viewModel.revealSelectedScreenshotInFinder()
                }
            }

        }
        .foregroundStyle(.white)
    }
}

private enum UsageLimitPalette {
    static func color(for provider: UsageLimitProvider) -> Color {
        switch provider {
        case .claudeCode:
            Color(red: 0.96, green: 0.47, blue: 0.22)
        case .codex:
            Color(red: 0.28, green: 0.78, blue: 0.62)
        }
    }
}

private extension UsageLimitWindow {
    var percentageText: String {
        guard let usedPercentage else {
            return "--"
        }

        return "\(Int(usedPercentage.rounded()))%"
    }

    var resetText: String {
        guard isAvailable else {
            return "Unavailable"
        }

        guard let resetAt else {
            return "No reset"
        }

        let remaining = resetAt.timeIntervalSinceNow
        guard remaining > 0 else {
            return "Reset due"
        }

        if remaining < 60 * 60 {
            return "\(Int(ceil(remaining / 60)))m"
        }

        if remaining < 24 * 60 * 60 {
            return "\(Int(ceil(remaining / 3_600)))h"
        }

        return UsageLimitResetFormatter.string(from: resetAt)
    }

    var accessibilityText: String {
        guard isAvailable else {
            return "unavailable"
        }

        if let resetAt {
            return "\(percentageText), resets \(UsageLimitResetFormatter.string(from: resetAt))"
        }

        return percentageText
    }
}

private enum UsageLimitResetFormatter {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HugeIcon(icon, size: 14, color: .white.opacity(isHovered ? 0.96 : 0.7))
                .frame(width: 30, height: 30)
                .background(
                    Color.white.opacity(isHovered ? 0.14 : 0),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
        .pointingHandCursor()
        .overlay(alignment: .bottomTrailing) {
            if isHovered {
                Text(tooltip)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Color.white.opacity(0.14), in: Capsule())
                    .offset(y: 26)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    .allowsHitTesting(false)
            }
        }
        .zIndex(isHovered ? 20 : 0)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
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
                dragImage: {
                    IslandDragPreview.screenshot(
                        thumbnail: thumbnail,
                        imagePath: item.imagePath
                    )
                },
                onClick: action,
                onDragChanged: onDragChanged
            ) {
                ZStack {
                    if let image = thumbnail {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 142, height: 142)
                            .clipped()
                    } else {
                        HugeIcon(.image, size: 26, color: .white.opacity(0.58))
                            .help("Screenshot thumbnail")
                    }
                }
                .frame(width: 142, height: 142, alignment: .center)
                .background(Color.white.opacity(isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.72) : .clear, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .help("Click card to copy screenshot")
            .accessibilityLabel("Screenshot")
            .accessibilityAddTraits(.isButton)

            DeleteCardButton(isVisible: isDeleteVisible, isHovered: $isDeleteHovered, action: deleteAction)
                .padding(5)
        }
        .onHover { isHovered = $0 }
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
                dragImage: { IslandDragPreview.text(item.preview) },
                onClick: action,
                onDragChanged: onDragChanged
            ) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.preview)
                        .font(AssistFont.roundedFootnote(.medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(7)
                }
                .padding(12)
                .frame(width: 142, height: 142, alignment: .topLeading)
                .background(Color.white.opacity(isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.72) : .clear, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .help("Click card to copy text")
            .accessibilityLabel("Text clip")
            .accessibilityAddTraits(.isButton)

            DeleteCardButton(isVisible: isDeleteVisible, isHovered: $isDeleteHovered, action: deleteAction)
                .padding(5)
        }
        .onHover { isHovered = $0 }
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

    static func text(_ preview: String) -> NSImage {
        cardImage { rect in
            let insetRect = rect.insetBy(dx: 12, dy: 12)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byTruncatingTail

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.86),
                .paragraphStyle: paragraphStyle
            ]

            NSString(string: preview).draw(
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

    private var red: Color {
        Color(hex: 0xFF453A)
    }

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())

            Button(action: action) {
                HugeIcon(.trash, size: 12, color: red.opacity(isHovered ? 1 : 0.9))
                    .frame(width: 24, height: 24)
                    .background(
                        red.opacity(isHovered ? 0.26 : 0.16),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
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
