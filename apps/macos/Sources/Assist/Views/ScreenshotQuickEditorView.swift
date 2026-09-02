import AppKit
import SwiftUI

struct ScreenshotQuickEditorView: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ScreenshotEditorMetrics.cornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenshotEditorCanvas(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    // Until the pointer arrives, the divider drains to show the auto-close window.
                    if let session = viewModel.session, !viewModel.hasPointerEntered {
                        ScreenshotEditorEntryProgress(presentedAt: session.presentedAt)
                            .transition(.opacity.animation(.easeOut(duration: 0.2)))
                    }
                }

            ScreenshotEditorControls(viewModel: viewModel)
                .frame(height: ScreenshotEditorMetrics.controlsHeight)
        }
        .background { EditorCardBackground() }
        .clipShape(cardShape)
        .overlay {
            cardShape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.18), .white.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .preferredColorScheme(.dark)
        .onExitCommand {
            viewModel.requestCancel()
        }
    }
}

private struct EditorCardBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial)
            Color(hex: 0x0B0B0D).opacity(0.74)
        }
    }
}

// MARK: - Canvas

private struct ScreenshotEditorCanvas: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        GeometryReader { geometry in
            let inset = ScreenshotEditorMetrics.canvasInset
            let bounds = CGRect(origin: .zero, size: geometry.size).insetBy(dx: inset, dy: inset)
            let image = viewModel.previewImage
            let imageRect = image.map { Self.aspectFitRect(imageSize: $0.size, in: bounds) } ?? .zero
            let isStyling = viewModel.activeTool == .style

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.32)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .clipShape(RoundedRectangle(cornerRadius: isStyling ? 0 : 3, style: .continuous))
                        .shadow(color: .black.opacity(isStyling ? 0 : 0.35), radius: 10, y: 4)
                        .offset(x: imageRect.minX, y: imageRect.minY)
                        .id(isStyling)
                        .transition(.opacity)

                    if !isStyling {
                        ScreenshotEditorInteractionLayer(
                            viewModel: viewModel,
                            imageSize: imageRect.size
                        )
                        .frame(width: imageRect.width, height: imageRect.height)
                        .offset(x: imageRect.minX, y: imageRect.minY)
                    }
                }
            }
            .animation(.easeOut(duration: 0.18), value: isStyling)
            .clipped()
        }
        .accessibilityLabel("Screenshot editor preview")
    }

    private static func aspectFitRect(imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private struct ScreenshotEditorInteractionLayer: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    let imageSize: CGSize
    @State private var isDragging = false

    var body: some View {
        ZStack {
            if viewModel.activeTool == .crop {
                CropSelectionOverlay(normalizedRect: viewModel.draft.cropRect)
            }

            if viewModel.activeTool == .blur,
               let index = viewModel.activeBlurStrokeIndex,
               viewModel.draft.blurStrokes.indices.contains(index) {
                BlurStrokeOverlay(stroke: viewModel.draft.blurStrokes[index])
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(editorGesture)
        }
        .frame(width: imageSize.width, height: imageSize.height)
        .clipped()
        .cursor(viewModel.activeTool == .crop ? .crosshair : .pointingHand)
    }

    private var editorGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = normalized(value.location)
                if isDragging {
                    viewModel.updateGesture(to: point)
                } else {
                    isDragging = true
                    viewModel.beginGesture(at: point)
                }
            }
            .onEnded { value in
                viewModel.endGesture(at: normalized(value.location))
                isDragging = false
            }
    }

    private func normalized(_ point: CGPoint) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        return CGPoint(x: point.x / imageSize.width, y: point.y / imageSize.height)
            .clampedToUnitSquare
    }
}

private struct CropSelectionOverlay: View {
    let normalizedRect: CGRect

    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(
                x: normalizedRect.minX * geometry.size.width,
                y: normalizedRect.minY * geometry.size.height,
                width: normalizedRect.width * geometry.size.width,
                height: normalizedRect.height * geometry.size.height
            ).standardized
            let isFullFrame = normalizedRect == ScreenshotEditDraft.fullImageCrop

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRect(rect)
                }
                .fill(Color.black.opacity(isFullFrame ? 0 : 0.5), style: FillStyle(eoFill: true))

                Path { path in
                    path.addRect(rect)
                    if rect.width > 48, rect.height > 48 {
                        for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
                            path.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
                            path.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
                            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
                        }
                    }
                }
                .stroke(
                    Color.white.opacity(isFullFrame ? 0 : 0.7),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )

                Path { path in
                    let arm = min(14, rect.width / 3, rect.height / 3)
                    guard arm > 2 else { return }
                    for (corner, dx, dy) in [
                        (CGPoint(x: rect.minX, y: rect.minY), CGFloat(1), CGFloat(1)),
                        (CGPoint(x: rect.maxX, y: rect.minY), CGFloat(-1), CGFloat(1)),
                        (CGPoint(x: rect.minX, y: rect.maxY), CGFloat(1), CGFloat(-1)),
                        (CGPoint(x: rect.maxX, y: rect.maxY), CGFloat(-1), CGFloat(-1))
                    ] {
                        path.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
                        path.addLine(to: corner)
                        path.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
                    }
                }
                .stroke(
                    Color.white.opacity(isFullFrame ? 0 : 1),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            }
            .allowsHitTesting(false)
        }
    }
}

private struct BlurStrokeOverlay: View {
    let stroke: ScreenshotBlurStroke

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard let first = stroke.points.first else { return }
                path.move(
                    to: CGPoint(
                        x: first.x * geometry.size.width,
                        y: first.y * geometry.size.height
                    )
                )
                for point in stroke.points.dropFirst() {
                    path.addLine(
                        to: CGPoint(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        )
                    )
                }
            }
            .stroke(
                Color.white.opacity(0.34),
                style: StrokeStyle(
                    lineWidth: min(geometry.size.width, geometry.size.height) * stroke.diameterFraction,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Controls

private struct ScreenshotEditorControls: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ToolSegmentedControl(selection: $viewModel.activeTool)

                Spacer(minLength: 0)

                EditorIconButton(
                    icon: .refresh,
                    tooltip: "Reset all edits",
                    isEnabled: viewModel.hasEdits && !viewModel.isSaving
                ) {
                    viewModel.reset()
                }

                SaveButton(isSaving: viewModel.isSaving) {
                    viewModel.requestSave()
                }
            }
            .frame(height: 32)

            ZStack(alignment: .topLeading) {
                switch viewModel.activeTool {
                case .crop:
                    CropOptions(viewModel: viewModel)
                        .transition(optionsTransition)
                case .blur:
                    BlurOptions(viewModel: viewModel)
                        .transition(optionsTransition)
                case .style:
                    StyleOptions(viewModel: viewModel)
                        .transition(optionsTransition)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 56, alignment: .top)
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: viewModel.activeTool)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var optionsTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity
        )
    }
}

private struct ToolSegmentedControl: View {
    @Binding var selection: ScreenshotEditorTool
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ScreenshotEditorTool.allCases) { tool in
                let isSelected = tool == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        selection = tool
                    }
                } label: {
                    HStack(spacing: 6) {
                        HugeIcon(tool.icon, size: 13, color: .white.opacity(isSelected ? 0.98 : 0.62))
                        Text(tool.title)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.62))
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 26)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .matchedGeometryEffect(id: "segment", in: highlight)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("\(tool.title) tool")
                .accessibilityLabel("\(tool.title) tool")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .pointingHandCursor()
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }
}

private struct CropOptions: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                HugeIcon(.aspectRatio, size: 12, color: .white.opacity(0.42))
                    .padding(.trailing, 2)
                ForEach(ScreenshotCropAspect.allCases) { aspect in
                    EditorChip(
                        title: aspect.title,
                        isSelected: viewModel.cropAspect == aspect,
                        accessibilityLabel: "\(aspect.title) crop ratio"
                    ) {
                        viewModel.cropAspect = aspect
                    }
                }
            }

            EditorHint(
                viewModel.draft.isCropped
                    ? "Drag again to redo the crop."
                    : "Drag across the screenshot to crop it."
            )
        }
    }
}

private struct BlurOptions: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                ForEach(ScreenshotBlurBrush.allCases) { brush in
                    BrushSizeButton(brush: brush, isSelected: viewModel.blurBrush == brush) {
                        viewModel.blurBrush = brush
                    }
                }
            }

            EditorHint("Paint over anything you want hidden.")
        }
    }
}

private struct StyleOptions: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                BackdropSwatch(
                    background: .none,
                    wallpaper: nil,
                    isSelected: viewModel.draft.style.background == .none
                ) {
                    viewModel.selectBackground(.none)
                }

                ForEach(ScreenshotGradientPreset.all) { preset in
                    BackdropSwatch(
                        background: .gradient(preset),
                        wallpaper: nil,
                        isSelected: viewModel.draft.style.background == .gradient(preset)
                    ) {
                        viewModel.selectBackground(.gradient(preset))
                    }
                }

                if let wallpaper = viewModel.wallpaperImage {
                    BackdropSwatch(
                        background: .desktop,
                        wallpaper: wallpaper,
                        isSelected: viewModel.draft.style.background == .desktop
                    ) {
                        viewModel.selectBackground(.desktop)
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.wallpaperImage == nil)

            HStack(spacing: 12) {
                EditorSlider(
                    title: "Padding",
                    value: viewModel.draft.style.paddingFraction,
                    range: ScreenshotFrameStyle.paddingRange,
                    onChange: { viewModel.setPadding($0) },
                    onInteractionChanged: { viewModel.setInteracting($0) }
                )

                EditorSlider(
                    title: "Corners",
                    value: viewModel.draft.style.cornerRadiusFraction,
                    range: ScreenshotFrameStyle.cornerRadiusRange,
                    onChange: { viewModel.setCornerRadius($0) },
                    onInteractionChanged: { viewModel.setInteracting($0) }
                )

                EditorChip(
                    title: "Shadow",
                    isSelected: viewModel.draft.style.showsShadow,
                    accessibilityLabel: "Toggle drop shadow"
                ) {
                    viewModel.toggleShadow()
                }
            }
        }
    }
}

// MARK: - Controls: building blocks

private struct EditorHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.42))
            .lineLimit(1)
            .contentTransition(.opacity)
            .animation(.easeOut(duration: 0.16), value: text)
    }
}

private struct EditorChip: View {
    let title: String
    let isSelected: Bool
    let accessibilityLabel: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(isHovered ? 0.95 : 0.74))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(
                    isSelected ? Color.white : Color.white.opacity(isHovered ? 0.14 : 0.08),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }
}

private struct BrushSizeButton: View {
    let brush: ScreenshotBlurBrush
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var dotDiameter: CGFloat {
        switch brush {
        case .fine: 6
        case .medium: 10
        case .bold: 14
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isSelected ? 0.16 : (isHovered ? 0.1 : 0.06)))
                Circle()
                    .fill(Color.white.opacity(isSelected ? 1 : 0.55))
                    .frame(width: dotDiameter, height: dotDiameter)
            }
            .frame(width: 26, height: 26)
            .overlay {
                Circle().strokeBorder(Color.white.opacity(isSelected ? 0.5 : 0), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(brush.title)
        .accessibilityLabel(brush.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .animation(.spring(response: 0.26, dampingFraction: 0.8), value: isSelected)
    }
}

private struct BackdropSwatch: View {
    let background: ScreenshotBackground
    let wallpaper: CGImage?
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                swatchFill
                    .clipShape(Circle())
                    .frame(width: 22, height: 22)

                Circle()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 22, height: 22)

                Circle()
                    .strokeBorder(Color.white, lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.8)
            }
            .frame(width: 28, height: 28)
            .scaleEffect(isHovered && !isSelected ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .help(background.title)
        .accessibilityLabel(background.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: isSelected)
        .animation(.easeOut(duration: 0.14), value: isHovered)
    }

    @ViewBuilder
    private var swatchFill: some View {
        switch background {
        case .none:
            ZStack {
                Circle().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 1.5, height: 16)
                    .rotationEffect(.degrees(45))
            }
        case let .gradient(preset):
            LinearGradient(
                colors: preset.colors.map { Color(hex: $0) },
                startPoint: UnitPoint(x: preset.startPoint.x, y: preset.startPoint.y),
                endPoint: UnitPoint(x: preset.endPoint.x, y: preset.endPoint.y)
            )
        case .desktop:
            if let wallpaper {
                Image(nsImage: NSImage(cgImage: wallpaper, size: .zero))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.12)
            }
        }
    }
}

private struct EditorSlider: View {
    let title: String
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    let onChange: (CGFloat) -> Void
    let onInteractionChanged: (Bool) -> Void
    @State private var isHovered = false
    @State private var isDragging = false

    private let knobDiameter: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            GeometryReader { geometry in
                let span = range.upperBound - range.lowerBound
                let fraction = span > 0 ? (value - range.lowerBound) / span : 0
                let travel = max(0, geometry.size.width - knobDiameter)
                let knobX = travel * fraction

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: knobX + knobDiameter / 2, height: 4)

                    Circle()
                        .fill(Color.white)
                        .frame(width: knobDiameter, height: knobDiameter)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .scaleEffect(isDragging ? 1.18 : (isHovered ? 1.08 : 1))
                        .offset(x: knobX)
                }
                .frame(height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { drag in
                            if !isDragging {
                                isDragging = true
                                onInteractionChanged(true)
                            }
                            let position = (drag.location.x - knobDiameter / 2) / max(travel, 1)
                            let clamped = min(max(position, 0), 1)
                            onChange(range.lowerBound + clamped * span)
                        }
                        .onEnded { _ in
                            isDragging = false
                            onInteractionChanged(false)
                        }
                )
            }
            .frame(height: 24)
        }
        .frame(maxWidth: .infinity)
        .onHover { isHovered = $0 }
        .pointingHandCursor()
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isDragging)
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

private struct EditorIconButton: View {
    let icon: HugeIconKind
    let tooltip: String
    var isEnabled = true
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HugeIcon(
                icon,
                size: 14,
                color: .white.opacity(isEnabled ? (isHovered ? 0.96 : 0.7) : 0.28)
            )
            .frame(width: 30, height: 30)
            .background(
                Color.white.opacity(isEnabled && isHovered ? 0.12 : 0),
                in: Circle()
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(tooltip)
        .accessibilityLabel(tooltip)
        .pointingHandCursor(isEnabled: isEnabled)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .animation(.easeOut(duration: 0.14), value: isEnabled)
    }
}

private struct SaveButton: View {
    let isSaving: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                HugeIcon(.check, size: 12, color: .black)
                Text(isSaving ? "Saving" : "Save")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Color.white.opacity(isSaving ? 0.7 : 1), in: Capsule())
            .scaleEffect(isHovered && !isSaving ? 1.03 : 1)
            .shadow(color: .white.opacity(isHovered && !isSaving ? 0.22 : 0), radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .help("Save edited screenshot (Return)")
        .accessibilityLabel("Save edited screenshot")
        .pointingHandCursor(isEnabled: !isSaving)
        .keyboardShortcut(.return, modifiers: [])
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isHovered)
        .animation(.easeOut(duration: 0.16), value: isSaving)
    }
}

private struct ScreenshotEditorEntryProgress: View {
    let presentedAt: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            GeometryReader { geometry in
                let elapsed = context.date.timeIntervalSince(presentedAt)
                let remaining = max(0, 1 - elapsed / ScreenshotEditorMetrics.entryWindow)

                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: geometry.size.width * remaining, height: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(height: 2)
        .offset(y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Cursor helper

private struct CursorModifier: ViewModifier {
    let cursor: NSCursor
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    guard !isPushed else { return }
                    cursor.push()
                    isPushed = true
                } else if isPushed {
                    NSCursor.pop()
                    isPushed = false
                }
            }
            .onDisappear {
                guard isPushed else { return }
                NSCursor.pop()
                isPushed = false
            }
    }
}

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        modifier(CursorModifier(cursor: cursor))
    }
}
