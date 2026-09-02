import AppKit
import CoreImage

struct ScreenshotEditRenderer {
    /// A blurred and optionally cropped bitmap plus the point scale of its source image.
    struct FlatRender {
        let image: CGImage
        let pointsPerPixel: CGFloat

        var pointSize: CGSize {
            CGSize(
                width: CGFloat(image.width) * pointsPerPixel,
                height: CGFloat(image.height) * pointsPerPixel
            )
        }
    }

    private let context = CIContext(options: [.cacheIntermediates: true])

    /// Renders the finished screenshot: blur strokes, crop, then backdrop styling.
    func render(image: NSImage, draft: ScreenshotEditDraft, wallpaper: CGImage? = nil) throws -> NSImage {
        let flat = try renderFlat(image: image, draft: draft, applyingCrop: true)
        let styled = try applyStyle(draft.style, to: flat.image, wallpaper: wallpaper)
        return NSImage(
            cgImage: styled,
            size: CGSize(
                width: CGFloat(styled.width) * flat.pointsPerPixel,
                height: CGFloat(styled.height) * flat.pointsPerPixel
            )
        )
    }

    /// Applies blur strokes and (optionally) the crop without any backdrop styling.
    func renderFlat(
        image: NSImage,
        draft: ScreenshotEditDraft,
        applyingCrop: Bool,
        maxPreviewDimension: CGFloat? = nil
    ) throws -> FlatRender {
        guard var sourceCGImage = image.bestCGImage else {
            throw AppError.imageEncodingFailed
        }
        if let maxPreviewDimension, let scaled = Self.downscaled(sourceCGImage, maxDimension: maxPreviewDimension) {
            sourceCGImage = scaled
        }
        let pointsPerPixel = sourceCGImage.width > 0
            ? image.size.width / CGFloat(sourceCGImage.width)
            : 1

        var composited = sourceCGImage
        if !draft.blurStrokes.isEmpty {
            composited = try blurred(sourceCGImage, strokes: draft.blurStrokes)
        }

        let output = applyingCrop ? crop(composited, toNormalized: draft.cropRect) : composited
        return FlatRender(image: output, pointsPerPixel: pointsPerPixel)
    }

    /// Crops using normalized top-left coordinates, matching the editor's gesture space.
    func crop(_ image: CGImage, toNormalized normalizedRect: CGRect) -> CGImage {
        let normalized = normalizedRect.standardized.intersection(ScreenshotEditDraft.fullImageCrop)
        guard normalized.width > 0, normalized.height > 0 else { return image }

        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let pixelRect = CGRect(
            x: normalized.minX * bounds.width,
            y: normalized.minY * bounds.height,
            width: normalized.width * bounds.width,
            height: normalized.height * bounds.height
        ).integral.intersection(bounds)

        guard pixelRect.width >= 1, pixelRect.height >= 1 else { return image }
        return image.cropping(to: pixelRect) ?? image
    }

    /// Frames the bitmap with padding, rounded corners, a soft shadow, and a backdrop.
    func applyStyle(_ style: ScreenshotFrameStyle, to image: CGImage, wallpaper: CGImage?) throws -> CGImage {
        guard !style.isStandard else { return image }

        let width = image.width
        let height = image.height
        let base = CGFloat(min(width, height))
        let padding = Int((base * style.paddingFraction).rounded())
        let canvasWidth = width + padding * 2
        let canvasHeight = height + padding * 2

        guard canvasWidth > 0, canvasHeight > 0,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let canvas = CGContext(
                data: nil,
                width: canvasWidth,
                height: canvasHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw AppError.imageEncodingFailed
        }

        canvas.interpolationQuality = .high
        let canvasRect = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
        drawBackground(style.background, in: canvasRect, context: canvas, wallpaper: wallpaper)

        let imageRect = CGRect(x: padding, y: padding, width: width, height: height)
        let radius = min(base * style.cornerRadiusFraction, imageRect.width / 2, imageRect.height / 2)
        let framePath = CGPath(
            roundedRect: imageRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        if style.showsShadow {
            canvas.saveGState()
            canvas.setShadow(
                offset: CGSize(width: 0, height: -base * 0.035),
                blur: base * 0.09,
                color: CGColor(gray: 0, alpha: 0.42)
            )
            canvas.addPath(framePath)
            canvas.setFillColor(CGColor(gray: 0, alpha: 1))
            canvas.fillPath()
            canvas.restoreGState()
        }

        canvas.saveGState()
        canvas.addPath(framePath)
        canvas.clip()
        canvas.draw(image, in: imageRect)
        canvas.restoreGState()

        guard let output = canvas.makeImage() else {
            throw AppError.imageEncodingFailed
        }
        return output
    }

    // MARK: - Backdrops

    private func drawBackground(
        _ background: ScreenshotBackground,
        in rect: CGRect,
        context: CGContext,
        wallpaper: CGImage?
    ) {
        switch background {
        case .none:
            return
        case let .gradient(preset):
            drawGradient(preset, in: rect, context: context)
        case .desktop:
            if let wallpaper {
                drawAspectFill(wallpaper, in: rect, context: context)
            } else if let fallback = ScreenshotGradientPreset.all.first(where: { $0.id == "graphite" }) {
                drawGradient(fallback, in: rect, context: context)
            }
        }
    }

    private func drawGradient(_ preset: ScreenshotGradientPreset, in rect: CGRect, context: CGContext) {
        let colors = preset.colors.map { Self.color(hex: $0) }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil) else {
            return
        }

        // Presets use a top-left origin; Core Graphics uses bottom-left.
        let start = CGPoint(
            x: rect.minX + preset.startPoint.x * rect.width,
            y: rect.minY + (1 - preset.startPoint.y) * rect.height
        )
        let end = CGPoint(
            x: rect.minX + preset.endPoint.x * rect.width,
            y: rect.minY + (1 - preset.endPoint.y) * rect.height
        )
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(
            gradient,
            start: start,
            end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private func drawAspectFill(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let imageSize = CGSize(width: image.width, height: image.height)
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        context.saveGState()
        context.clip(to: rect)
        context.draw(image, in: drawRect)
        context.restoreGState()
    }

    private static func color(hex: UInt32) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }

    // MARK: - Blur

    private func blurred(_ sourceCGImage: CGImage, strokes: [ScreenshotBlurStroke]) throws -> CGImage {
        let source = CIImage(cgImage: sourceCGImage)
        let radiusFraction = strokes.map(\.blurRadiusFraction).max() ?? 0
        let radius = max(1, min(source.extent.width, source.extent.height) * radiusFraction)
        let blurredImage = source
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: source.extent)

        guard let maskCGImage = makeBlurMask(
            size: CGSize(width: sourceCGImage.width, height: sourceCGImage.height),
            strokes: strokes
        ) else {
            throw AppError.imageEncodingFailed
        }

        let composited = blurredImage.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: source,
                kCIInputMaskImageKey: CIImage(cgImage: maskCGImage)
            ]
        )

        guard let output = context.createCGImage(composited, from: source.extent) else {
            throw AppError.imageEncodingFailed
        }
        return output
    }

    private func makeBlurMask(size: CGSize, strokes: [ScreenshotBlurStroke]) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0,
              let maskContext = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            return nil
        }

        maskContext.setFillColor(gray: 0, alpha: 1)
        maskContext.fill(CGRect(origin: .zero, size: size))
        maskContext.setStrokeColor(gray: 1, alpha: 1)
        maskContext.setFillColor(gray: 1, alpha: 1)
        maskContext.setLineCap(.round)
        maskContext.setLineJoin(.round)

        for stroke in strokes where !stroke.points.isEmpty {
            let lineWidth = max(1, min(size.width, size.height) * stroke.diameterFraction)
            maskContext.setLineWidth(lineWidth)
            let points = stroke.points.map { point in
                CGPoint(
                    x: point.x * size.width,
                    y: (1 - point.y) * size.height
                )
            }

            if let first = points.first, points.count == 1 {
                maskContext.fillEllipse(
                    in: CGRect(
                        x: first.x - lineWidth / 2,
                        y: first.y - lineWidth / 2,
                        width: lineWidth,
                        height: lineWidth
                    )
                )
                continue
            }

            guard let first = points.first else { continue }
            maskContext.beginPath()
            maskContext.move(to: first)
            for point in points.dropFirst() {
                maskContext.addLine(to: point)
            }
            maskContext.strokePath()
        }

        return maskContext.makeImage()
    }

    // MARK: - Scaling

    private static func downscaled(_ image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let ratio = min(maxDimension / width, maxDimension / height, 1)
        guard ratio < 1 else { return image }

        let targetWidth = max(1, Int((width * ratio).rounded()))
        let targetHeight = max(1, Int((height * ratio).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
    }
}

private extension NSImage {
    var bestCGImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }
}
