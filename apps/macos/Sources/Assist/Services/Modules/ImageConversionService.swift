import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Converts dropped images to JPEG, PNG, HEIC, or PDF on a background task,
/// writing each result beside its original.
@MainActor
final class ImageConversionService: ObservableObject {
    static let resultLimit = 12

    @Published var options: ImageConversionOptions {
        didSet {
            guard options != oldValue, let data = try? JSONEncoder().encode(options) else { return }
            defaults.set(data, forKey: Keys.options)
        }
    }
    @Published private(set) var results: [ImageConversionResult] = []
    @Published private(set) var isConverting = false

    private let defaults: UserDefaults
    private var pendingBatches = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        options = defaults.data(forKey: Keys.options)
            .flatMap { try? JSONDecoder().decode(ImageConversionOptions.self, from: $0) }
            ?? ImageConversionOptions()
    }

    /// Converts the images among `urls` with the current options. Other files
    /// are reported as skipped.
    func convert(_ urls: [URL]) {
        let fileURLs = urls.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return }

        let options = options
        pendingBatches += 1
        isConverting = true
        DebugLogger.log("modules.converter.start", [
            "count": "\(fileURLs.count)",
            "format": options.format.rawValue
        ])

        Task {
            let converted = await Task.detached(priority: .userInitiated) {
                fileURLs.map { ImageConverter.convert($0, options: options) }
            }.value
            finish(converted)
        }
    }

    func reveal(_ result: ImageConversionResult) {
        guard let outputURL = result.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    func clearResults() {
        results = []
    }

    private func finish(_ converted: [ImageConversionResult]) {
        results = Array((converted + results).prefix(Self.resultLimit))
        pendingBatches = max(pendingBatches - 1, 0)
        isConverting = pendingBatches > 0
        DebugLogger.log("modules.converter.finish", [
            "succeeded": "\(converted.filter { $0.errorMessage == nil }.count)",
            "failed": "\(converted.filter { $0.errorMessage != nil }.count)"
        ])
    }
}

/// The ImageIO and Core Graphics work behind the converter. It holds no state,
/// so it runs safely off the main thread.
enum ImageConverter {
    static func convert(_ source: URL, options: ImageConversionOptions) -> ImageConversionResult {
        let sourceName = source.lastPathComponent
        let originalBytes = fileSize(of: source)

        func failure(_ message: String) -> ImageConversionResult {
            ImageConversionResult(
                id: UUID(),
                sourceName: sourceName,
                outputURL: nil,
                originalBytes: originalBytes,
                outputBytes: nil,
                errorMessage: message
            )
        }

        guard ImageConversionNaming.isImage(source) else {
            return failure("Not an image")
        }
        guard let image = loadImage(at: source, maxPixels: options.maxDimension.pixels) else {
            return failure("Could not read this image")
        }

        let stagedURL = source.deletingLastPathComponent()
            .appendingPathComponent(".assist-conversion-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: stagedURL) }

        if let maxFileSizeKB = options.maxFileSizeKB, options.format.usesQuality {
            guard ImageConversionOptions.fileSizeRange.contains(maxFileSizeKB) else {
                return failure("Target size must be between 1 and 20,000 KB")
            }
            let raster = options.format == .jpeg ? flattenedOnWhite(image) ?? image : image
            guard let data = rasterData(
                raster,
                source: source,
                format: options.format,
                maximumQuality: options.quality.compression,
                targetBytes: maxFileSizeKB * 1_024
            ) else {
                return failure("Could not fit within \(maxFileSizeKB) KB")
            }
            do {
                try data.write(to: stagedURL, options: .atomic)
            } catch {
                return failure("Could not write \(options.format.title)")
            }
        } else {
            let didWrite: Bool
            switch options.format {
            case .pdf:
                didWrite = writePDF(image, to: stagedURL)
            case .jpeg:
                didWrite = writeRaster(flattenedOnWhite(image) ?? image, to: stagedURL, options: options)
            case .png, .heic:
                didWrite = writeRaster(image, to: stagedURL, options: options)
            }
            guard didWrite else { return failure("Could not write \(options.format.title)") }
        }

        let fileManager = FileManager.default
        var outputURL = ImageConversionNaming.outputURL(for: source, format: options.format) { url in
            fileManager.fileExists(atPath: url.path)
        }
        while true {
            do {
                try fileManager.linkItem(at: stagedURL, to: outputURL)
                break
            } catch {
                guard fileManager.fileExists(atPath: outputURL.path) else {
                    return failure("Could not write \(options.format.title)")
                }
                outputURL = ImageConversionNaming.outputURL(for: source, format: options.format) { url in
                    fileManager.fileExists(atPath: url.path)
                }
            }
        }

        return ImageConversionResult(
            id: UUID(),
            sourceName: sourceName,
            outputURL: outputURL,
            originalBytes: originalBytes,
            outputBytes: fileSize(of: outputURL),
            errorMessage: nil
        )
    }

    /// Decodes the first frame upright (applying EXIF orientation), scaled
    /// down so its longest side is at most `maxPixels`. It never scales up.
    private static func loadImage(at url: URL, maxPixels: Int?) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }

        let longestSide = max(width, height)
        let targetSide = min(maxPixels ?? longestSide, longestSide)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: targetSide
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
    }

    private static func writeRaster(_ image: CGImage, to url: URL, options: ImageConversionOptions) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            options.format.contentType.identifier as CFString,
            1,
            nil
        ) else { return false }

        var properties: [CFString: Any] = [:]
        if options.format.usesQuality {
            properties[kCGImageDestinationLossyCompressionQuality] = options.quality.compression
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private static func rasterData(
        _ image: CGImage,
        source: URL,
        format: ImageConversionFormat,
        maximumQuality: Double,
        targetBytes: Int
    ) -> Data? {
        var current = image
        for _ in 0..<8 {
            if let initial = encode(current, format: format, quality: maximumQuality), initial.count <= targetBytes {
                return initial
            }

            let minimumQuality = 0.08
            if let minimum = encode(current, format: format, quality: minimumQuality) {
                if minimum.count <= targetBytes {
                    var best = minimum
                    var low = minimumQuality
                    var high = maximumQuality
                    for _ in 0..<6 {
                        let midpoint = (low + high) / 2
                        guard let candidate = encode(current, format: format, quality: midpoint) else { break }
                        if candidate.count <= targetBytes {
                            best = candidate
                            low = midpoint
                        } else {
                            high = midpoint
                        }
                    }
                    return best
                }

                let longestSide = max(current.width, current.height)
                guard longestSide > 128 else { return nil }
                let scale = min(0.85, max(0.5, sqrt(Double(targetBytes) / Double(minimum.count)) * 0.9))
                let nextSide = max(128, Int(Double(longestSide) * scale))
                guard nextSide < longestSide,
                      let smaller = loadImage(at: source, maxPixels: nextSide) else { return nil }
                current = format == .jpeg ? flattenedOnWhite(smaller) ?? smaller : smaller
            } else {
                return nil
            }
        }
        return nil
    }

    private static func encode(_ image: CGImage, format: ImageConversionFormat, quality: Double) -> Data? {
        guard let data = CFDataCreateMutable(kCFAllocatorDefault, 0),
              let destination = CGImageDestinationCreateWithData(data, format.contentType.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    private static func writePDF(_ image: CGImage, to url: URL) -> Bool {
        var mediaBox = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return false }
        context.beginPDFPage(nil)
        context.draw(image, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
        return true
    }

    private static func flattenedOnWhite(_ image: CGImage) -> CGImage? {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return nil
        default:
            break
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }

    private static func fileSize(of url: URL) -> Int64? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }
    }
}

private enum Keys {
    static let options = "modules.converter.options"
}
