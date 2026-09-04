import AppKit
import SwiftUI

private typealias EditorTokens = AssistDesignTokens.ScreenshotEditor

struct ScreenshotQuickEditorView: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ScreenshotEditorMetrics.cornerRadius, style: .continuous)
    }

    var body: some View {
        GeometryReader { geometry in
            let previewHeight = ScreenshotEditorMetrics.previewAreaHeight(
                forCardHeight: geometry.size.height
            )
            let controlsHeight = ScreenshotEditorMetrics.controlsAreaHeight(
                forCardHeight: geometry.size.height
            )

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ScreenshotEditorHeader(viewModel: viewModel)
                        .frame(height: ScreenshotEditorMetrics.headerHeight)

                    ScreenshotEditorCanvas(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: previewHeight)
                .overlay(alignment: .bottom) {
                    // Until the pointer arrives, the divider drains to show the auto-close window.
                    if let session = viewModel.session, !viewModel.hasPointerEntered {
                        ScreenshotEditorEntryProgress(presentedAt: session.presentedAt)
                            .transition(.opacity.animation(EditorTokens.Motion.progressReveal))
                    }
                }

                ScreenshotEditorControls(viewModel: viewModel)
                    .frame(height: controlsHeight)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background { EditorCardBackground() }
        .clipShape(cardShape)
        .overlay {
            cardShape.strokeBorder(
                LinearGradient(
                    colors: [
                        EditorTokens.foreground.opacity(EditorTokens.Opacity.cardBorderTop),
                        EditorTokens.foreground.opacity(EditorTokens.Opacity.cardBorderBottom)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: EditorTokens.Layout.cardStroke
            )
        }
        .preferredColorScheme(.dark)
        .onExitCommand {
            viewModel.requestCancel()
        }
    }
}

/// Header controls live inside the preview allocation without covering the screenshot.
private struct ScreenshotEditorHeader: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        HStack(spacing: 0) {
            EditorIconButton(
                icon: .close,
                tooltip: "Close without saving edits. The original screenshot stays saved.",
                isEnabled: !viewModel.isSaving
            ) {
                viewModel.requestCancel()
            }

            Spacer(minLength: 0)

            Text(headerTitle)
                .font(EditorTokens.Typography.header)
                .foregroundStyle(
                    EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.secondary)
                )
                .lineLimit(1)
                .accessibilityLabel(headerTitle)

            Spacer(minLength: 0)

            EditorIconButton(
                icon: viewModel.isExpanded ? .collapse : .expand,
                tooltip: viewModel.isExpanded
                    ? "Shrink the editor"
                    : "Expand the editor for a closer look",
                isEnabled: !viewModel.isSaving
            ) {
                viewModel.toggleExpanded()
            }
        }
        .padding(.horizontal, EditorTokens.Layout.headerHorizontalInset)
    }

    private var headerTitle: String {
        if viewModel.isSaving {
            return "Saving edits…"
        }
        return viewModel.hasPointerEntered
            ? "Screenshot editor"
            : "Screenshot saved · Hover to edit"
    }
}

private struct EditorCardBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial)
            EditorTokens.surface.opacity(EditorTokens.Opacity.surface)
        }
    }
}

// MARK: - Canvas

private struct ScreenshotEditorCanvas: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        GeometryReader { geometry in
            let inset = ScreenshotEditorMetrics.canvasInset
            let topInset = ScreenshotEditorMetrics.canvasTopInset
            let bounds = CGRect(
                x: inset,
                y: topInset,
                width: max(0, geometry.size.width - inset * 2),
                height: max(0, geometry.size.height - topInset - inset)
            )
            let image = viewModel.previewImage
            let imageRect = image.map { Self.aspectFitRect(imageSize: $0.size, in: bounds) } ?? .zero
            let isStyling = viewModel.activeTool == .style

            ZStack(alignment: .topLeading) {
                EditorTokens.surface

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: EditorTokens.Layout.canvasBackdropBlur)
                        .opacity(EditorTokens.Opacity.canvasBackdrop)
                        .overlay {
                            EditorTokens.canvas.opacity(EditorTokens.Opacity.canvasBackdropScrim)
                        }
                        .allowsHitTesting(false)

                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: isStyling ? 0 : EditorTokens.Layout.imageRadius,
                                style: .continuous
                            )
                        )
                        .shadow(
                            color: EditorTokens.canvas.opacity(
                                isStyling ? 0 : EditorTokens.Opacity.imageShadow
                            ),
                            radius: EditorTokens.Layout.imageShadowRadius,
                            y: EditorTokens.Layout.imageShadowY
                        )
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
            .animation(EditorTokens.Motion.canvasChange, value: isStyling)
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
                let stroke = viewModel.draft.blurStrokes[index]
                if let image = viewModel.previewImage {
                    LiveBlurStrokeOverlay(image: image, stroke: stroke)
                }
                BlurStrokeOverlay(stroke: stroke)
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
                .fill(
                    EditorTokens.canvas.opacity(
                        isFullFrame ? 0 : EditorTokens.Opacity.cropScrim
                    ),
                    style: FillStyle(eoFill: true)
                )

                Path { path in
                    path.addRect(rect)
                    if rect.width > EditorTokens.Layout.cropGridMinimum,
                       rect.height > EditorTokens.Layout.cropGridMinimum {
                        for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
                            path.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
                            path.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
                            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
                        }
                    }
                }
                .stroke(
                    EditorTokens.foreground.opacity(
                        isFullFrame ? 0 : EditorTokens.Opacity.cropGrid
                    ),
                    style: StrokeStyle(
                        lineWidth: EditorTokens.Layout.cropGridStroke,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                Path { path in
                    let arm = min(
                        EditorTokens.Layout.cropCornerArm,
                        rect.width / 3,
                        rect.height / 3
                    )
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
                    EditorTokens.foreground.opacity(isFullFrame ? 0 : 1),
                    style: StrokeStyle(
                        lineWidth: EditorTokens.Layout.cropCornerStroke,
                        lineCap: .round,
                        lineJoin: .round
                    )
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
                EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.disabled),
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

private struct LiveBlurStrokeOverlay: View {
    let image: NSImage
    let stroke: ScreenshotBlurStroke

    var body: some View {
        GeometryReader { geometry in
            let blurRadius = min(geometry.size.width, geometry.size.height)
                * stroke.blurRadiusFraction

            Image(nsImage: image)
                .resizable()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .blur(radius: blurRadius)
                .mask {
                    BlurStrokeMask(stroke: stroke)
                }
                .clipped()
                .allowsHitTesting(false)
        }
    }
}

private struct BlurStrokeMask: View {
    let stroke: ScreenshotBlurStroke

    var body: some View {
        GeometryReader { geometry in
            let lineWidth = min(geometry.size.width, geometry.size.height)
                * stroke.diameterFraction

            if let first = stroke.points.first, stroke.points.count == 1 {
                Circle()
                    .fill(EditorTokens.foreground)
                    .frame(width: lineWidth, height: lineWidth)
                    .position(
                        x: first.x * geometry.size.width,
                        y: first.y * geometry.size.height
                    )
            } else {
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
                    EditorTokens.foreground,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
    }
}

// MARK: - Controls

private struct ScreenshotEditorControls: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTokens.Layout.controlsRowSpacing) {
            HStack(spacing: AssistDesignTokens.Spacing.medium) {
                ToolChipPicker(selection: $viewModel.activeTool)

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
            .frame(height: EditorTokens.Layout.primaryRowHeight)

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
            .frame(height: EditorTokens.Layout.optionsRowHeight, alignment: .top)
            .animation(EditorTokens.Motion.optionsChange, value: viewModel.activeTool)
        }
        .padding(.horizontal, EditorTokens.Layout.controlsHorizontalInset)
        .padding(.top, EditorTokens.Layout.controlsTopInset)
        .padding(.bottom, EditorTokens.Layout.controlsBottomInset)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(EditorTokens.foreground.opacity(EditorTokens.Opacity.divider))
                .frame(height: EditorTokens.Layout.dividerHeight)
        }
    }

    private var optionsTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(
                with: .offset(y: EditorTokens.Layout.transitionOffset)
            ),
            removal: .opacity
        )
    }
}

private struct ToolChipPicker: View {
    @Binding var selection: ScreenshotEditorTool

    var body: some View {
        HStack(spacing: AssistDesignTokens.Spacing.xSmall) {
            ForEach(ScreenshotEditorTool.allCases) { tool in
                EditorToolChip(tool: tool, isSelected: tool == selection) {
                    withAnimation(EditorTokens.Motion.toolSelection) {
                        selection = tool
                    }
                }
            }
        }
    }
}

private struct EditorToolChip: View {
    let tool: ScreenshotEditorTool
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AssistDesignTokens.Spacing.xSmall) {
                HugeIcon(
                    tool.icon,
                    size: AssistDesignTokens.Icon.regular,
                    color: foregroundColor
                )

                Text(tool.title)
                    .font(EditorTokens.Typography.tool)
                    .foregroundStyle(foregroundColor)
            }
            .padding(.horizontal, EditorTokens.Layout.toolChipHorizontalInset)
            .frame(height: EditorTokens.Layout.toolChipHeight)
            .background(backgroundColor, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("\(tool.title) tool")
        .accessibilityLabel("\(tool.title) tool")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(EditorTokens.Motion.hover, value: isHovered)
        .animation(EditorTokens.Motion.toolSelection, value: isSelected)
    }

    private var foregroundColor: Color {
        if isSelected {
            return EditorTokens.inverseForeground.opacity(AssistDesignTokens.Opacity.primary)
        }
        return EditorTokens.foreground.opacity(
            isHovered
                ? AssistDesignTokens.Opacity.primary
                : AssistDesignTokens.Opacity.secondary
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return EditorTokens.foreground
        }
        return isHovered
            ? EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.hoverSurface)
            : .clear
    }
}

private struct CropOptions: View {
    @ObservedObject var viewModel: ScreenshotEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.small) {
            HStack(spacing: AssistDesignTokens.Spacing.xSmall) {
                HugeIcon(
                    .aspectRatio,
                    size: AssistDesignTokens.Icon.small,
                    color: EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.subtle)
                )
                    .padding(.trailing, AssistDesignTokens.Spacing.xxxSmall)
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
        VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.small) {
            HStack(spacing: AssistDesignTokens.Spacing.xSmall) {
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
        VStack(alignment: .leading, spacing: AssistDesignTokens.Spacing.xSmall) {
            HStack(spacing: AssistDesignTokens.Spacing.small) {
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
                    .transition(
                        .scale(scale: EditorTokens.Scale.wallpaperRevealStart)
                            .combined(with: .opacity)
                    )
                }
            }
            .animation(EditorTokens.Motion.wallpaperReveal, value: viewModel.wallpaperImage == nil)

            HStack(spacing: AssistDesignTokens.Spacing.large) {
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
            .font(EditorTokens.Typography.label)
            .foregroundStyle(
                EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.subtle)
            )
            .lineLimit(1)
            .contentTransition(.opacity)
            .animation(EditorTokens.Motion.labelChange, value: text)
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
                .font(EditorTokens.Typography.chip)
                .foregroundStyle(
                    isSelected
                        ? EditorTokens.inverseForeground
                        : EditorTokens.foreground.opacity(
                            isHovered
                                ? AssistDesignTokens.Opacity.primary
                                : AssistDesignTokens.Opacity.secondary
                        )
                )
                .lineLimit(1)
                .padding(.horizontal, EditorTokens.Layout.chipHorizontalInset)
                .frame(height: EditorTokens.Layout.chipHeight)
                .background(
                    isSelected
                        ? EditorTokens.foreground
                        : (isHovered
                            ? EditorTokens.foreground.opacity(
                                AssistDesignTokens.Opacity.hoverSurface
                            )
                            : .clear),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(EditorTokens.Motion.hover, value: isHovered)
        .animation(EditorTokens.Motion.hover, value: isSelected)
    }
}

private struct BrushSizeButton: View {
    let brush: ScreenshotBlurBrush
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var dotDiameter: CGFloat {
        switch brush {
        case .fine: EditorTokens.Layout.brushFineDot
        case .medium: EditorTokens.Layout.brushMediumDot
        case .bold: EditorTokens.Layout.brushBoldDot
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        EditorTokens.foreground.opacity(
                            isSelected
                                ? AssistDesignTokens.Opacity.hoverSurface
                                : (isHovered
                                    ? EditorTokens.Opacity.brushHoverSurface
                                    : EditorTokens.Opacity.brushIdleSurface)
                        )
                    )
                Circle()
                    .fill(
                        EditorTokens.foreground.opacity(
                            isSelected ? 1 : AssistDesignTokens.Opacity.muted
                        )
                    )
                    .frame(width: dotDiameter, height: dotDiameter)
            }
            .frame(
                width: EditorTokens.Layout.brushButton,
                height: EditorTokens.Layout.brushButton
            )
            .overlay {
                Circle().strokeBorder(
                    EditorTokens.foreground.opacity(
                        isSelected ? EditorTokens.Opacity.brushSelectedStroke : 0
                    ),
                    lineWidth: EditorTokens.Layout.cardStroke
                )
            }
        }
        .buttonStyle(.plain)
        .help(brush.title)
        .accessibilityLabel(brush.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(EditorTokens.Motion.hover, value: isHovered)
        .animation(EditorTokens.Motion.selection, value: isSelected)
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
                    .frame(
                        width: EditorTokens.Layout.swatch,
                        height: EditorTokens.Layout.swatch
                    )

                Circle()
                    .strokeBorder(
                        EditorTokens.foreground.opacity(EditorTokens.Opacity.swatchBorder),
                        lineWidth: EditorTokens.Layout.cardStroke
                    )
                    .frame(
                        width: EditorTokens.Layout.swatch,
                        height: EditorTokens.Layout.swatch
                    )

                Circle()
                    .strokeBorder(
                        EditorTokens.foreground,
                        lineWidth: EditorTokens.Layout.selectedSwatchStroke
                    )
                    .frame(
                        width: EditorTokens.Layout.selectedSwatch,
                        height: EditorTokens.Layout.selectedSwatch
                    )
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(
                        isSelected ? 1 : EditorTokens.Scale.swatchSelectionStart
                    )
            }
            .frame(
                width: EditorTokens.Layout.selectedSwatch,
                height: EditorTokens.Layout.selectedSwatch
            )
            .scaleEffect(
                isHovered && !isSelected ? EditorTokens.Scale.swatchHover : 1
            )
        }
        .buttonStyle(.plain)
        .help(background.title)
        .accessibilityLabel(background.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .pointingHandCursor()
        .onHover { isHovered = $0 }
        .animation(EditorTokens.Motion.selection, value: isSelected)
        .animation(EditorTokens.Motion.hover, value: isHovered)
    }

    @ViewBuilder
    private var swatchFill: some View {
        switch background {
        case .none:
            ZStack {
                Circle().fill(
                    EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.quietSurface)
                )
                Capsule()
                    .fill(
                        EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.secondary)
                    )
                    .frame(
                        width: EditorTokens.Layout.emptySwatchMarkWidth,
                        height: EditorTokens.Layout.emptySwatchMarkHeight
                    )
                    .rotationEffect(
                        .degrees(EditorTokens.Layout.emptySwatchMarkRotation)
                    )
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
                EditorTokens.foreground.opacity(EditorTokens.Opacity.sliderTrack)
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

    private let knobDiameter = EditorTokens.Layout.sliderKnob

    var body: some View {
        HStack(spacing: AssistDesignTokens.Spacing.small) {
            Text(title)
                .font(EditorTokens.Typography.label)
                .foregroundStyle(
                    EditorTokens.foreground.opacity(AssistDesignTokens.Opacity.muted)
                )
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            GeometryReader { geometry in
                let span = range.upperBound - range.lowerBound
                let fraction = span > 0 ? (value - range.lowerBound) / span : 0
                let travel = max(0, geometry.size.width - knobDiameter)
                let knobX = travel * fraction

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(EditorTokens.foreground.opacity(EditorTokens.Opacity.sliderTrack))
                        .frame(height: EditorTokens.Layout.sliderTrackHeight)

                    Capsule()
                        .fill(EditorTokens.foreground.opacity(EditorTokens.Opacity.sliderFill))
                        .frame(
                            width: knobX + knobDiameter / 2,
                            height: EditorTokens.Layout.sliderTrackHeight
                        )

                    Circle()
                        .fill(EditorTokens.foreground)
                        .frame(width: knobDiameter, height: knobDiameter)
                        .shadow(
                            color: EditorTokens.canvas.opacity(EditorTokens.Opacity.sliderShadow),
                            radius: AssistDesignTokens.Spacing.xxxSmall,
                            y: 1
                        )
                        .scaleEffect(
                            isDragging
                                ? EditorTokens.Scale.sliderDrag
                                : (isHovered ? EditorTokens.Scale.sliderHover : 1)
                        )
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
            .frame(height: EditorTokens.Layout.sliderHeight)
        }
        .frame(maxWidth: .infinity)
        .onHover { isHovered = $0 }
        .pointingHandCursor()
        .animation(EditorTokens.Motion.sliderDrag, value: isDragging)
        .animation(EditorTokens.Motion.hover, value: isHovered)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityHint("Adjust with VoiceOver or the arrow keys")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjust(by: 1)
            case .decrement:
                adjust(by: -1)
            @unknown default:
                break
            }
        }
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .left, .down:
                adjust(by: -1)
            case .right, .up:
                adjust(by: 1)
            default:
                break
            }
        }
    }

    private func adjust(by stepCount: CGFloat) {
        let step = (range.upperBound - range.lowerBound) / 20
        onChange(min(max(value + step * stepCount, range.lowerBound), range.upperBound))
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
                size: AssistDesignTokens.Icon.regular,
                color: EditorTokens.foreground.opacity(
                    isEnabled
                        ? (isHovered
                            ? AssistDesignTokens.Opacity.primary
                            : AssistDesignTokens.Opacity.secondary)
                        : AssistDesignTokens.Opacity.disabled
                )
            )
            .frame(
                width: EditorTokens.Layout.iconButton,
                height: EditorTokens.Layout.iconButton
            )
            .background(
                EditorTokens.foreground.opacity(
                    isEnabled && isHovered ? AssistDesignTokens.Opacity.hoverSurface : 0
                ),
                in: Circle()
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(tooltip)
        .accessibilityLabel(tooltip)
        .pointingHandCursor(isEnabled: isEnabled)
        .onHover { isHovered = $0 }
        .animation(EditorTokens.Motion.hover, value: isHovered)
        .animation(EditorTokens.Motion.hover, value: isEnabled)
    }
}

private struct SaveButton: View {
    let isSaving: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AssistDesignTokens.Spacing.xSmall) {
                HugeIcon(
                    .check,
                    size: AssistDesignTokens.Icon.small,
                    color: EditorTokens.inverseForeground
                )
                Text(isSaving ? "Saving" : "Save")
                    .font(EditorTokens.Typography.action)
                    .foregroundStyle(EditorTokens.inverseForeground)
                    .lineLimit(1)
            }
            .padding(.horizontal, EditorTokens.Layout.saveHorizontalInset)
            .frame(height: EditorTokens.Layout.saveHeight)
            .background(
                EditorTokens.foreground.opacity(
                    isSaving ? AssistDesignTokens.Opacity.secondary : 1
                ),
                in: Capsule()
            )
            .scaleEffect(
                isHovered && !isSaving ? EditorTokens.Scale.saveHover : 1
            )
            .shadow(
                color: EditorTokens.foreground.opacity(
                    isHovered && !isSaving ? EditorTokens.Opacity.saveGlow : 0
                ),
                radius: AssistDesignTokens.Spacing.small
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .help("Save edits to this screenshot")
        .accessibilityLabel("Save edited screenshot")
        .pointingHandCursor(isEnabled: !isSaving)
        .keyboardShortcut(.return, modifiers: [])
        .onHover { isHovered = $0 }
        .animation(EditorTokens.Motion.saveHover, value: isHovered)
        .animation(EditorTokens.Motion.saving, value: isSaving)
    }
}

private struct ScreenshotEditorEntryProgress: View {
    let presentedAt: Date

    var body: some View {
        TimelineView(
            .animation(minimumInterval: EditorTokens.Layout.progressFrameInterval)
        ) { context in
            GeometryReader { geometry in
                let elapsed = context.date.timeIntervalSince(presentedAt)
                let remaining = max(0, 1 - elapsed / ScreenshotEditorMetrics.entryWindow)

                Rectangle()
                    .fill(EditorTokens.foreground.opacity(EditorTokens.Opacity.progress))
                    .frame(
                        width: geometry.size.width * remaining,
                        height: EditorTokens.Layout.progressHeight
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(height: EditorTokens.Layout.progressHeight)
        .offset(y: EditorTokens.Layout.cardStroke)
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
