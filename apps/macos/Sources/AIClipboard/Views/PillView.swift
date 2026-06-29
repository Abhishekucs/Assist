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
        .interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
    }

    private var shouldShowLoadingBorder: Bool {
        settings.showLoadingBorder && viewModel.isBusy
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                CollapsedIslandHeader(viewModel: viewModel)
                    .frame(
                        width: collapsedSize.width,
                        height: collapsedSize.height
                    )
                    .opacity(viewModel.isCollapsedContentVisible ? 1 : 0)
                    .transaction { transaction in
                        transaction.animation = nil
                    }

                ExpandedIslandView(viewModel: viewModel)
                    .frame(
                        width: expandedSize.width,
                        height: expandedSize.height,
                        alignment: .top
                    )
                    .opacity(viewModel.isExpandedContentVisible ? 1 : 0)
                    .allowsHitTesting(viewModel.isExpandedContentVisible)
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
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
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.latestItem)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }
}

private struct CollapsedIslandHeader: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text(viewModel.statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.latestItem != nil {
                Image(systemName: "photo")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(.horizontal, 18)
    }
}

private struct MovingNotchBorder: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    private let segmentLength = 0.34

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
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
        VStack(alignment: .leading, spacing: 10) {
            ExpandedIslandHeader(viewModel: viewModel)
                .frame(height: 34)

            if !viewModel.historyItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.historyItems) { item in
                            switch item {
                            case let .screenshot(capture):
                                CaptureGalleryCard(
                                    item: capture,
                                    thumbnail: viewModel.thumbnail(for: capture),
                                    isSelected: item.id == viewModel.selectedItem?.id,
                                    isFileSelected: viewModel.selectedFileIDs.contains(capture.id)
                                ) {
                                    viewModel.selectScreenshot(
                                        capture,
                                        extendingFileSelection: NSApp.currentEvent?.modifierFlags.contains(.command) == true
                                    )
                                } deleteAction: {
                                    viewModel.delete(item)
                                }
                            case let .text(textClip):
                                TextClipGalleryCard(
                                    item: textClip,
                                    isSelected: item.id == viewModel.selectedItem?.id
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
                        .font(.system(size: 16, weight: .semibold))

                    Text("Hold Control to annotate, press Control + Option for a clean screenshot, or copy text.")
                        .font(.system(size: 13))
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
            Text("Recent Items")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .textCase(.uppercase)

            Spacer()

            Button {
                viewModel.openControls()
            } label: {
                Capsule()
                    .fill(.black)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.white)
                            .imageScale(.medium)
                    }
            }
            .buttonStyle(.plain)
            .help("Open controls")

            if viewModel.canCopySelectedImage {
                Button {
                    viewModel.copyLatestImage()
                } label: {
                    Capsule()
                        .fill(.black)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundStyle(.white)
                                .imageScale(.medium)
                        }
                }
                .buttonStyle(.plain)
                .help("Copy image")
            }

            if viewModel.canCopySelectedFiles {
                Button {
                    viewModel.copySelectedScreenshotFiles()
                } label: {
                    Capsule()
                        .fill(.black)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.white)
                                .imageScale(.medium)
                        }
                }
                .buttonStyle(.plain)
                .help("Copy \(viewModel.selectedFileCount) screenshot file\(viewModel.selectedFileCount == 1 ? "" : "s")")
            }

            if viewModel.canRevealSelectedScreenshot {
                Button {
                    viewModel.revealSelectedScreenshotInFinder()
                } label: {
                    Capsule()
                        .fill(.black)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "folder")
                                .foregroundStyle(.white)
                                .imageScale(.medium)
                        }
                }
                .buttonStyle(.plain)
                .help("Reveal screenshot in Finder")
            }

            if viewModel.selectedItem != nil {
                Button {
                    viewModel.copyLatestContext()
                } label: {
                    Capsule()
                        .fill(.black)
                        .frame(width: 30, height: 30)
                        .overlay {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.white)
                                .imageScale(.medium)
                        }
                }
                .buttonStyle(.plain)
                .help(viewModel.canCopySelectedImage ? "Copy context" : "Copy text")
            }
        }
        .foregroundStyle(.white)
    }
}

private struct DebugActionsView: View {
    @ObservedObject var viewModel: PillViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    viewModel.testScreenshot()
                } label: {
                    Label("Test Screenshot", systemImage: "camera")
                }

                Button {
                    viewModel.testOverlay()
                } label: {
                    Label("Test Overlay", systemImage: "scribble")
                }

                Button {
                    viewModel.openDebugLog()
                } label: {
                    Label("Log", systemImage: "doc.text.magnifyingglass")
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .tint(.white)

            if let diagnosticMessage = viewModel.diagnosticMessage {
                Text(diagnosticMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }
        }
    }
}

private struct CaptureGalleryCard: View {
    let item: CaptureItem
    let thumbnail: NSImage?
    let isSelected: Bool
    let isFileSelected: Bool
    let action: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))

                        if let image = thumbnail {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 126, height: 96)
                                .clipped()
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 126, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(item.createdAt, style: .time)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(8)
                .frame(width: 142, height: 142, alignment: .topLeading)
                .background(Color.white.opacity(isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.72) : Color.white.opacity(0.12), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .onDrag {
                item.dragProvider
            }

            FileSelectionBadge(isSelected: isFileSelected)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            DeleteCardButton(action: deleteAction)
                .padding(5)
        }
    }
}

private struct TextClipGalleryCard: View {
    let item: TextClipItem
    let isSelected: Bool
    let action: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))

                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))

                                Spacer()

                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Text(item.preview)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(5)
                        }
                        .padding(10)
                    }
                    .frame(width: 126, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(item.createdAt, style: .time)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(8)
                .frame(width: 142, height: 142, alignment: .topLeading)
                .background(Color.white.opacity(isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.72) : Color.white.opacity(0.12), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .onDrag {
                item.dragProvider
            }

            DeleteCardButton(action: deleteAction)
                .padding(5)
        }
    }
}

private struct FileSelectionBadge: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color.black.opacity(isSelected ? 0.78 : 0.46))
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: isSelected ? "checkmark" : "circle")
                    .font(.system(size: isSelected ? 10 : 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.52))
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(isSelected ? 0.55 : 0.16), lineWidth: 1)
            }
            .help(isSelected ? "Selected for file copy" : "Command-click to select multiple files")
            .allowsHitTesting(false)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.black.opacity(0.74))
                .frame(width: 22, height: 22)
                .overlay {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
        }
        .buttonStyle(.plain)
        .help("Delete item")
    }
}
