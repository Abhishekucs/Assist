import SwiftUI

struct PillView: View {
    @ObservedObject var viewModel: PillViewModel
    let onHoverChanged: (Bool) -> Void

    private var isIslandChromeVisible: Bool {
        viewModel.isExpanded
    }

    private var chromeSize: CGSize {
        viewModel.isExpanded ? PillChromeMetrics.expandedSize : PillChromeMetrics.collapsedSize
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
        viewModel.isBusy || (viewModel.isExpanded && !viewModel.isExpandedContentVisible)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                CollapsedIslandHeader(viewModel: viewModel)
                    .frame(
                        width: PillChromeMetrics.collapsedSize.width,
                        height: PillChromeMetrics.collapsedSize.height
                    )
                    .opacity(viewModel.isCollapsedContentVisible ? 1 : 0)
                    .transaction { transaction in
                        transaction.animation = nil
                    }

                if viewModel.isExpandedContentVisible {
                    ExpandedIslandView(viewModel: viewModel)
                        .frame(
                            width: PillChromeMetrics.expandedSize.width,
                            height: PillChromeMetrics.expandedSize.height,
                            alignment: .top
                        )
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .transition(.opacity.animation(.easeOut(duration: 0.08)))
                }
            }
            .frame(width: chromeSize.width, height: chromeSize.height, alignment: .top)
            .animation(islandAnimation, value: viewModel.isExpanded)
            .background {
                BoringNotchShape(
                    topCornerRadius: chromeTopCornerRadius,
                    bottomCornerRadius: chromeBottomCornerRadius
                )
                    .fill(Color.black.opacity(isIslandChromeVisible ? 0.94 : 0.99))
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

private struct BoringNotchShape: Shape {
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
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            control: CGPoint(x: rect.minX + topRadius, y: rect.minY)
        )
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
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()

        return path
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

            if !viewModel.items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.items) { item in
                            CaptureGalleryCard(
                                item: item,
                                thumbnail: viewModel.thumbnail(for: item),
                                isSelected: item.id == viewModel.latestItem?.id
                            ) {
                                viewModel.latestItem = item
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            } else {
                VStack(alignment: .center, spacing: 10) {
                    Text("No captures yet")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Hold Control to annotate. Press Control + Option for a clean screenshot.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    DebugActionsView(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
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
            Text("Recent Captures")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .textCase(.uppercase)

            Spacer()

            if !viewModel.items.isEmpty {
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
                .help("Copy context")
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))

                    if let image = thumbnail {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 126, height: 78)
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 126, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(item.context.summary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .frame(width: 126, alignment: .leading)

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
    }
}
