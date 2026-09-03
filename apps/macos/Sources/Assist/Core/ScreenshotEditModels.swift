import AppKit
import CoreGraphics
import Foundation

enum ScreenshotEditorTool: String, CaseIterable, Equatable, Identifiable {
    case crop
    case blur
    case style

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crop: "Crop"
        case .blur: "Blur"
        case .style: "Style"
        }
    }

    var icon: HugeIconKind {
        switch self {
        case .crop: .crop
        case .blur: .blur
        case .style: .paintBoard
        }
    }
}

enum ScreenshotCropAspect: String, CaseIterable, Equatable, Identifiable {
    case free
    case square
    case fourByThree
    case threeByTwo
    case sixteenByNine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: "Free"
        case .square: "1:1"
        case .fourByThree: "4:3"
        case .threeByTwo: "3:2"
        case .sixteenByNine: "16:9"
        }
    }

    /// Pixel width divided by pixel height, or nil for an unconstrained crop.
    var ratio: CGFloat? {
        switch self {
        case .free: nil
        case .square: 1
        case .fourByThree: 4.0 / 3.0
        case .threeByTwo: 3.0 / 2.0
        case .sixteenByNine: 16.0 / 9.0
        }
    }

    /// Builds a normalized crop rectangle anchored at `start` that grows toward `point`.
    /// When the aspect is fixed, the rectangle keeps that pixel ratio and stays inside the image.
    func cropRect(from start: CGPoint, to point: CGPoint, imageAspectRatio: CGFloat) -> CGRect {
        let start = start.clampedToUnitSquare
        let point = point.clampedToUnitSquare
        var width = abs(point.x - start.x)
        var height = abs(point.y - start.y)

        if let ratio, imageAspectRatio > 0 {
            // The unit square is stretched by the image aspect, so convert the pixel ratio first.
            let normalizedRatio = ratio / imageAspectRatio
            if width > height * normalizedRatio {
                width = height * normalizedRatio
            } else {
                height = width / normalizedRatio
            }

            let availableWidth = point.x >= start.x ? 1 - start.x : start.x
            let availableHeight = point.y >= start.y ? 1 - start.y : start.y
            if width > availableWidth {
                width = availableWidth
                height = width / normalizedRatio
            }
            if height > availableHeight {
                height = availableHeight
                width = height * normalizedRatio
            }
        }

        return CGRect(
            x: point.x >= start.x ? start.x : start.x - width,
            y: point.y >= start.y ? start.y : start.y - height,
            width: width,
            height: height
        )
    }
}

enum ScreenshotBlurBrush: String, CaseIterable, Equatable, Identifiable {
    case fine
    case medium
    case bold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fine: "Fine brush"
        case .medium: "Medium brush"
        case .bold: "Bold brush"
        }
    }

    /// Brush diameter as a fraction of the shorter image side.
    var diameterFraction: CGFloat {
        switch self {
        case .fine: 0.05
        case .medium: 0.09
        case .bold: 0.15
        }
    }
}

struct ScreenshotBlurStroke: Equatable {
    var points: [CGPoint]
    let diameterFraction: CGFloat
    let blurRadiusFraction: CGFloat
}

struct ScreenshotGradientPreset: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let colors: [UInt32]
    /// Unit points with a top-left origin, matching SwiftUI's UnitPoint.
    let startPoint: CGPoint
    let endPoint: CGPoint

    static let all: [ScreenshotGradientPreset] = [
        ScreenshotGradientPreset(
            id: "sunset", name: "Sunset",
            colors: [0xFFB25C, 0xFF5E7E, 0x8E44FF],
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1)
        ),
        ScreenshotGradientPreset(
            id: "ocean", name: "Ocean",
            colors: [0x38D6FF, 0x2E62FF],
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1)
        ),
        ScreenshotGradientPreset(
            id: "aurora", name: "Aurora",
            colors: [0x3DF7C8, 0x3BA3FF, 0x8A5CFF],
            startPoint: CGPoint(x: 0, y: 1), endPoint: CGPoint(x: 1, y: 0)
        ),
        ScreenshotGradientPreset(
            id: "dusk", name: "Dusk",
            colors: [0x6A7BFF, 0x8E4EC6],
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1)
        ),
        ScreenshotGradientPreset(
            id: "peach", name: "Peach",
            colors: [0xFFE7CF, 0xFFB08A],
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1)
        ),
        ScreenshotGradientPreset(
            id: "mint", name: "Mint",
            colors: [0xDDFB8F, 0x8FE4B0],
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1)
        ),
        ScreenshotGradientPreset(
            id: "graphite", name: "Graphite",
            colors: [0x4A4A52, 0x15151A],
            startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)
        ),
        ScreenshotGradientPreset(
            id: "midnight", name: "Midnight",
            colors: [0x0F2027, 0x203A43, 0x2C5364],
            startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1)
        )
    ]
}

enum ScreenshotBackground: Equatable, Sendable {
    case none
    case gradient(ScreenshotGradientPreset)
    case desktop

    var title: String {
        switch self {
        case .none: "No backdrop"
        case let .gradient(preset): "\(preset.name) backdrop"
        case .desktop: "Desktop wallpaper backdrop"
        }
    }
}

struct ScreenshotFrameStyle: Equatable, Sendable {
    static let paddingRange: ClosedRange<CGFloat> = 0...0.24
    static let cornerRadiusRange: ClosedRange<CGFloat> = 0...0.08
    static let standard = ScreenshotFrameStyle()

    var background: ScreenshotBackground = .none
    /// Padding around the screenshot as a fraction of its shorter side.
    var paddingFraction: CGFloat = 0
    /// Corner radius as a fraction of the screenshot's shorter side.
    var cornerRadiusFraction: CGFloat = 0
    var showsShadow = false

    var isStandard: Bool { self == .standard }

    /// Picks a backdrop. The first pick also frames the screenshot so one click gives a finished look.
    mutating func select(_ background: ScreenshotBackground) {
        let isUntouched = paddingFraction == 0 && cornerRadiusFraction == 0 && !showsShadow
        self.background = background
        if background != .none, isUntouched {
            paddingFraction = 0.1
            cornerRadiusFraction = 0.024
            showsShadow = true
        }
    }
}

struct ScreenshotEditDraft: Equatable {
    static let fullImageCrop = CGRect(x: 0, y: 0, width: 1, height: 1)

    var cropRect = fullImageCrop
    var blurStrokes: [ScreenshotBlurStroke] = []
    var style = ScreenshotFrameStyle.standard

    var isCropped: Bool { cropRect != Self.fullImageCrop }

    var hasEdits: Bool {
        isCropped || !blurStrokes.isEmpty || !style.isStandard
    }
}

struct ScreenshotEditorSession {
    let id: UUID
    let capture: CaptureItem
    let originalImage: NSImage
    let presentedAt: Date
    /// Wallpaper of the captured display, used for the desktop backdrop when it can be read.
    var desktopImageURL: URL? = nil
}

struct ScreenshotEditorPresence: Equatable {
    private(set) var hasPointerEntered = false

    mutating func pointerEntered() {
        hasPointerEntered = true
    }

    /// The card follows the pointer away while it is only a preview. Once it holds unsaved edits,
    /// a stray pointer must not throw that work away, so closing becomes explicit.
    func shouldDismissWhenPointerExits(hasUnsavedEdits: Bool) -> Bool {
        hasPointerEntered && !hasUnsavedEdits
    }

    func shouldDismissWhenEntryWindowExpires() -> Bool {
        !hasPointerEntered
    }
}

enum ScreenshotEditorMetrics {
    static let preferredSize = CGSize(width: 384, height: 394)
    static let controlsHeight: CGFloat = 128
    /// Title-bar strip that carries the close and expand controls.
    static let headerHeight: CGFloat = 34
    static let canvasInset: CGFloat = 16
    /// The header already separates the screenshot from the card edge, so the canvas adds little.
    static let canvasTopInset: CGFloat = 4
    static let islandGap: CGFloat = 8
    static let screenMargin: CGFloat = 16
    static let cornerRadius: CGFloat = 18
    static let previewMaxDimension: CGFloat = 768
    /// The expanded card renders the screenshot far larger, so it needs a sharper preview.
    static let expandedPreviewMaxDimension: CGFloat = 2048
    /// Largest screenshot box the expanded card aims for before the screen clamps it.
    static let expandedImageBox = CGSize(width: 880, height: 560)
    /// Everything the card spends on chrome, so sizing and the canvas agree on the image box.
    static let cardChrome = CGSize(
        width: canvasInset * 2,
        height: headerHeight + canvasTopInset + canvasInset + controlsHeight
    )
    static let entryWindow: TimeInterval = 5
    /// How long the pointer may sit outside the editor before it closes.
    static let exitGracePeriod: TimeInterval = 0.45

    static func frame(
        below pillChromeFrame: CGRect,
        on screenFrame: CGRect,
        expanded: Bool = false,
        imageAspectRatio: CGFloat = 1
    ) -> CGRect {
        let available = CGSize(
            width: max(0, screenFrame.width - screenMargin * 2),
            height: max(0, pillChromeFrame.minY - islandGap - screenFrame.minY - screenMargin)
        )
        let size = expanded
            ? expandedSize(imageAspectRatio: imageAspectRatio, available: available)
            : collapsedSize(available: available)
        let proposedX = pillChromeFrame.midX - size.width / 2
        let minimumX = screenFrame.minX + screenMargin
        let maximumX = screenFrame.maxX - screenMargin - size.width
        let x = min(max(proposedX, minimumX), max(minimumX, maximumX))

        return CGRect(
            x: x,
            y: pillChromeFrame.minY - islandGap - size.height,
            width: size.width,
            height: size.height
        )
    }

    private static func collapsedSize(available: CGSize) -> CGSize {
        let scale = max(
            0,
            min(1, available.width / preferredSize.width, available.height / preferredSize.height)
        )
        return CGSize(
            width: floor(preferredSize.width * scale),
            height: floor(preferredSize.height * scale)
        )
    }

    /// Sizes the expanded card around the screenshot itself so the preview fills it edge to edge
    /// instead of floating in letterboxing.
    private static func expandedSize(imageAspectRatio: CGFloat, available: CGSize) -> CGSize {
        let collapsed = collapsedSize(available: available)
        let chrome = cardChrome
        let imageBox = CGSize(
            width: min(expandedImageBox.width, available.width - chrome.width),
            height: min(expandedImageBox.height, available.height - chrome.height)
        )
        guard imageAspectRatio > 0, imageBox.width > 0, imageBox.height > 0 else { return collapsed }

        var imageSize = CGSize(width: imageBox.width, height: imageBox.width / imageAspectRatio)
        if imageSize.height > imageBox.height {
            imageSize = CGSize(width: imageBox.height * imageAspectRatio, height: imageBox.height)
        }

        // Expanding must never shrink the card, so a narrow screenshot keeps the collapsed width.
        return CGSize(
            width: max(collapsed.width, floor(imageSize.width + chrome.width)),
            height: max(collapsed.height, floor(imageSize.height + chrome.height))
        )
    }
}

extension CGPoint {
    var clampedToUnitSquare: CGPoint {
        CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }
}
