import AppKit
import Combine
import ImageIO

@MainActor
final class ScreenshotEditorViewModel: ObservableObject {
    @Published private(set) var session: ScreenshotEditorSession?
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var hasPointerEntered = false
    @Published private(set) var isSaving = false
    @Published private(set) var draft = ScreenshotEditDraft()
    @Published private(set) var activeBlurStrokeIndex: Int?
    @Published private(set) var wallpaperImage: CGImage?
    @Published var cropAspect: ScreenshotCropAspect = .free
    @Published var blurBrush: ScreenshotBlurBrush = .medium
    @Published var activeTool: ScreenshotEditorTool = .crop {
        didSet {
            guard oldValue != activeTool else { return }
            refreshPreview()
        }
    }

    var onPointerEntered: ((UUID) -> Void)?
    var onPointerExited: ((UUID) -> Void)?
    var onSave: ((UUID, ScreenshotEditDraft) -> Void)?
    var onCancel: ((UUID) -> Void)?

    var hasEdits: Bool { draft.hasEdits }

    /// Pixel aspect ratio (width / height) of the screenshot being edited.
    var imageAspectRatio: CGFloat {
        guard let size = session?.originalImage.size, size.height > 0 else { return 1 }
        return size.width / size.height
    }

    private let renderer: ScreenshotEditRenderer
    private var flatPreview: ScreenshotEditRenderer.FlatRender?
    private var cropStartPoint: CGPoint?
    private var isInteracting = false
    private var pendingExitWorkItem: DispatchWorkItem?

    private static let minimumCropDimension: CGFloat = 0.025
    private static let blurPointSpacing: CGFloat = 0.004
    private static let blurRadiusFraction: CGFloat = 0.022
    private static let wallpaperMaxDimension: CGFloat = 1600

    init(renderer: ScreenshotEditRenderer = ScreenshotEditRenderer()) {
        self.renderer = renderer
    }

    // MARK: - Lifecycle

    func present(_ session: ScreenshotEditorSession) {
        pendingExitWorkItem?.cancel()
        pendingExitWorkItem = nil
        self.session = session
        hasPointerEntered = false
        isSaving = false
        isInteracting = false
        activeTool = .crop
        cropAspect = .free
        blurBrush = .medium
        draft = ScreenshotEditDraft()
        activeBlurStrokeIndex = nil
        cropStartPoint = nil
        wallpaperImage = nil
        rebuildFlatPreview()
        loadWallpaper(for: session)
    }

    func dismiss(sessionID: UUID) {
        guard session?.id == sessionID else { return }
        pendingExitWorkItem?.cancel()
        pendingExitWorkItem = nil
        session = nil
        previewImage = nil
        flatPreview = nil
        wallpaperImage = nil
        hasPointerEntered = false
        isSaving = false
        isInteracting = false
        draft = ScreenshotEditDraft()
        activeBlurStrokeIndex = nil
        cropStartPoint = nil
    }

    func setSaving(_ saving: Bool, sessionID: UUID) {
        guard session?.id == sessionID else { return }
        isSaving = saving
    }

    // MARK: - Pointer presence

    func pointerChanged(isInside: Bool) {
        guard let session else { return }

        if isInside {
            pendingExitWorkItem?.cancel()
            pendingExitWorkItem = nil
            guard !hasPointerEntered else { return }
            hasPointerEntered = true
            onPointerEntered?(session.id)
        } else if hasPointerEntered {
            scheduleExit()
        }
    }

    /// Marks a drag in progress so a stray pointer exit never closes the editor mid-gesture.
    func setInteracting(_ interacting: Bool) {
        isInteracting = interacting
    }

    private func scheduleExit() {
        pendingExitWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.completePendingExit()
        }
        pendingExitWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ScreenshotEditorMetrics.exitGracePeriod,
            execute: workItem
        )
    }

    private func completePendingExit() {
        pendingExitWorkItem = nil
        guard let session, hasPointerEntered else { return }
        if isInteracting {
            scheduleExit()
            return
        }
        onPointerExited?(session.id)
    }

    // MARK: - Actions

    func requestSave() {
        guard let session, !isSaving else { return }
        onSave?(session.id, draft)
    }

    func requestCancel() {
        guard let session, !isSaving else { return }
        onCancel?(session.id)
    }

    func reset() {
        guard session != nil, !isSaving else { return }
        draft = ScreenshotEditDraft()
        activeBlurStrokeIndex = nil
        cropStartPoint = nil
        rebuildFlatPreview()
    }

    // MARK: - Style

    func selectBackground(_ background: ScreenshotBackground) {
        guard session != nil, !isSaving else { return }
        draft.style.select(background)
        refreshPreview()
    }

    func setPadding(_ fraction: CGFloat) {
        guard session != nil, !isSaving else { return }
        draft.style.paddingFraction = fraction.clamped(to: ScreenshotFrameStyle.paddingRange)
        refreshPreview()
    }

    func setCornerRadius(_ fraction: CGFloat) {
        guard session != nil, !isSaving else { return }
        draft.style.cornerRadiusFraction = fraction.clamped(to: ScreenshotFrameStyle.cornerRadiusRange)
        refreshPreview()
    }

    func toggleShadow() {
        guard session != nil, !isSaving else { return }
        draft.style.showsShadow.toggle()
        refreshPreview()
    }

    // MARK: - Gestures

    func beginGesture(at point: CGPoint) {
        guard session != nil, !isSaving else { return }
        let point = point.clampedToUnitSquare
        isInteracting = true

        switch activeTool {
        case .crop:
            cropStartPoint = point
            draft.cropRect = CGRect(origin: point, size: .zero)
        case .blur:
            draft.blurStrokes.append(
                ScreenshotBlurStroke(
                    points: [point],
                    diameterFraction: blurBrush.diameterFraction,
                    blurRadiusFraction: Self.blurRadiusFraction
                )
            )
            activeBlurStrokeIndex = draft.blurStrokes.indices.last
        case .style:
            break
        }
    }

    func updateGesture(to point: CGPoint) {
        guard session != nil, !isSaving else { return }
        let point = point.clampedToUnitSquare

        switch activeTool {
        case .crop:
            guard let cropStartPoint else { return }
            draft.cropRect = cropAspect.cropRect(
                from: cropStartPoint,
                to: point,
                imageAspectRatio: imageAspectRatio
            )
        case .blur:
            guard let index = activeBlurStrokeIndex,
                  draft.blurStrokes.indices.contains(index) else { return }
            let lastPoint = draft.blurStrokes[index].points.last
            guard lastPoint.map({ hypot($0.x - point.x, $0.y - point.y) >= Self.blurPointSpacing }) ?? true else {
                return
            }
            draft.blurStrokes[index].points.append(point)
        case .style:
            break
        }
    }

    func endGesture(at point: CGPoint) {
        updateGesture(to: point)
        isInteracting = false

        switch activeTool {
        case .crop:
            cropStartPoint = nil
            if draft.cropRect.width < Self.minimumCropDimension ||
                draft.cropRect.height < Self.minimumCropDimension {
                draft.cropRect = ScreenshotEditDraft.fullImageCrop
            }
        case .blur:
            activeBlurStrokeIndex = nil
            rebuildFlatPreview()
        case .style:
            break
        }
    }

    // MARK: - Preview

    private func rebuildFlatPreview() {
        guard let session else { return }
        do {
            flatPreview = try renderer.renderFlat(
                image: session.originalImage,
                draft: draft,
                applyingCrop: false,
                maxPreviewDimension: ScreenshotEditorMetrics.previewMaxDimension
            )
        } catch {
            flatPreview = nil
            DebugLogger.log("screenshot-editor.preview.error", errorFields(error))
        }
        refreshPreview()
    }

    private func refreshPreview() {
        guard let session else { return }
        guard let flatPreview else {
            previewImage = session.originalImage
            return
        }

        switch activeTool {
        case .crop, .blur:
            previewImage = NSImage(cgImage: flatPreview.image, size: flatPreview.pointSize)
        case .style:
            let cropped = renderer.crop(flatPreview.image, toNormalized: draft.cropRect)
            let styled = (try? renderer.applyStyle(draft.style, to: cropped, wallpaper: wallpaperImage)) ?? cropped
            previewImage = NSImage(
                cgImage: styled,
                size: CGSize(
                    width: CGFloat(styled.width) * flatPreview.pointsPerPixel,
                    height: CGFloat(styled.height) * flatPreview.pointsPerPixel
                )
            )
        }
    }

    private func loadWallpaper(for session: ScreenshotEditorSession) {
        guard let url = session.desktopImageURL else { return }
        let sessionID = session.id
        let maxDimension = Self.wallpaperMaxDimension

        Task.detached(priority: .utility) {
            let payload = Self.loadImage(at: url, maxDimension: maxDimension).map(LoadedImage.init)
            await MainActor.run { [weak self] in
                guard let self, self.session?.id == sessionID else { return }
                self.wallpaperImage = payload?.image
                if self.activeTool == .style, self.draft.style.background == .desktop {
                    self.refreshPreview()
                }
            }
        }
    }

    private nonisolated static func loadImage(at url: URL, maxDimension: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func errorFields(_ error: Error) -> [String: String] {
        let nsError = error as NSError
        return [
            "domain": nsError.domain,
            "code": "\(nsError.code)",
            "description": nsError.localizedDescription
        ]
    }
}

/// CGImage is immutable, so handing one across the main-actor boundary is safe.
private struct LoadedImage: @unchecked Sendable {
    let image: CGImage
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
