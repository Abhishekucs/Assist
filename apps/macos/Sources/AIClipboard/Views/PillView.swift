import SwiftUI
import UniformTypeIdentifiers

struct PillView: View {
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var settings: PillSettings
    let onHoverChanged: (Bool) -> Void

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
        PillChromeMetrics.expandedSize(settings: settings)
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
                    ExpandedIslandView(viewModel: viewModel)
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
            .animation(islandAnimation, value: viewModel.copyFeedback != nil)
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

private struct CollapsedIslandHeader: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        HStack(spacing: 8) {
            if let feedback = viewModel.copyFeedback {
                CopyFeedbackRow(feedback: feedback)
                    .transition(
                        .opacity
                            .combined(with: .scale(scale: 0.96))
                            .animation(.easeOut(duration: 0.16))
                    )
            } else {
                Text(viewModel.statusText)
                    .font(AssistFont.roundedFootnote(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.latestItem != nil {
                    HugeIcon(.image, size: 13, color: .white.opacity(0.7))
                        .help("Recent item available")
                }
            }
        }
        .padding(.horizontal, 18)
        .animation(.easeOut(duration: 0.16), value: viewModel.copyFeedback)
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

    var body: some View {
        let historyItems = Array(viewModel.historyItems.prefix(24))
        let selectedID = viewModel.selectedItem?.id

        VStack(alignment: .leading, spacing: 10) {
            ExpandedIslandHeader(viewModel: viewModel)
                .frame(height: 34)

            if let issue = viewModel.captureIssue {
                CaptureIssuePanel(issue: issue, viewModel: viewModel)
            } else if !historyItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(historyItems) { item in
                            switch item {
                            case let .screenshot(capture):
                                CaptureGalleryCard(
                                    item: capture,
                                    thumbnail: viewModel.thumbnail(for: capture),
                                    isSelected: item.id == selectedID
                                ) {
                                    viewModel.selectScreenshot(capture)
                                } deleteAction: {
                                    viewModel.delete(item)
                                }
                            case let .text(textClip):
                                TextClipGalleryCard(
                                    item: textClip,
                                    isSelected: item.id == selectedID
                                ) {
                                    viewModel.copyTextItem(textClip)
                                } deleteAction: {
                                    viewModel.delete(item)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 1)
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
                        .lineLimit(1)
                        .truncationMode(.middle)
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

                DebugActionButton(title: "Log", icon: .document, tooltip: "Open the debug log") {
                    viewModel.openDebugLog()
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
    let action: () -> Void
    let deleteAction: () -> Void
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    private var isDeleteVisible: Bool {
        isHovered || isDeleteHovered
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
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
            .buttonStyle(.plain)
            .onDrag {
                item.dragProvider
            }
            .help("Select screenshot")

            DeleteCardButton(isVisible: isDeleteVisible, isHovered: $isDeleteHovered, action: deleteAction)
                .padding(5)
        }
        .onHover { isHovered = $0 }
    }
}

private struct TextClipGalleryCard: View {
    let item: TextClipItem
    let isSelected: Bool
    let action: () -> Void
    let deleteAction: () -> Void
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    private var isDeleteVisible: Bool {
        isHovered || isDeleteHovered
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
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
            .buttonStyle(.plain)
            .onDrag {
                item.dragProvider
            }
            .help("Click card to copy text")

            DeleteCardButton(isVisible: isDeleteVisible, isHovered: $isDeleteHovered, action: deleteAction)
                .padding(5)
        }
        .onHover { isHovered = $0 }
    }
}

private extension CaptureItem {
    var dragProvider: NSItemProvider {
        let imageURL = URL(fileURLWithPath: imagePath)

        if FileManager.default.fileExists(atPath: imageURL.path),
           let provider = NSItemProvider(contentsOf: imageURL) {
            return provider
        }

        return NSItemProvider(
            item: imageURL as NSSecureCoding,
            typeIdentifier: UTType.fileURL.identifier
        )
    }
}

private extension TextClipItem {
    var dragProvider: NSItemProvider {
        NSItemProvider(object: text as NSString)
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
