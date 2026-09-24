import Foundation
import UniformTypeIdentifiers

enum ImageConversionFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case jpeg
    case png
    case heic
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .heic: "HEIC"
        case .pdf: "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        case .pdf: "pdf"
        }
    }

    var contentType: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: .heic
        case .pdf: .pdf
        }
    }

    /// Lossy formats take a quality setting.
    var usesQuality: Bool {
        self == .jpeg || self == .heic
    }
}

/// The longest side of the converted image, in pixels. Images are never enlarged.
enum ImageMaxDimension: Int, CaseIterable, Identifiable, Codable, Sendable {
    case original = 0
    case large = 2560
    case medium = 1600
    case small = 1024

    var id: Int { rawValue }

    var title: String {
        self == .original ? "Original" : "\(rawValue) px"
    }

    var pixels: Int? {
        self == .original ? nil : rawValue
    }
}

enum ImageQuality: String, CaseIterable, Identifiable, Codable, Sendable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    var compression: Double {
        switch self {
        case .high: 0.9
        case .medium: 0.75
        case .low: 0.5
        }
    }
}

struct ImageConversionOptions: Equatable, Codable, Sendable {
    static let fileSizeRange = 1...20_000

    var format: ImageConversionFormat = .jpeg
    var maxDimension: ImageMaxDimension = .original
    var quality: ImageQuality = .high
    var maxFileSizeKB: Int?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case format, maxDimension, quality, maxFileSizeKB
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        format = try values.decodeIfPresent(ImageConversionFormat.self, forKey: .format) ?? .jpeg
        maxDimension = try values.decodeIfPresent(ImageMaxDimension.self, forKey: .maxDimension) ?? .original
        quality = try values.decodeIfPresent(ImageQuality.self, forKey: .quality) ?? .high
        let storedSize = try values.decodeIfPresent(Int.self, forKey: .maxFileSizeKB)
        maxFileSizeKB = storedSize.flatMap { Self.fileSizeRange.contains($0) ? $0 : nil }
    }
}

struct ImageConversionResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceName: String
    let outputURL: URL?
    let originalBytes: Int64?
    let outputBytes: Int64?
    let errorMessage: String?
}

enum ImageConversionNaming {
    /// Converted images are written beside the original, named after it, and
    /// never replace an existing file: "Photo.jpg", then "Photo 2.jpg".
    static func outputURL(
        for source: URL,
        format: ImageConversionFormat,
        fileExists: (URL) -> Bool
    ) -> URL {
        let directory = source.deletingLastPathComponent()
        let baseName = source.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(format.fileExtension)
        var suffix = 2
        while fileExists(candidate) {
            candidate = directory
                .appendingPathComponent("\(baseName) \(suffix)")
                .appendingPathExtension(format.fileExtension)
            suffix += 1
        }
        return candidate
    }

    /// Whether a dropped file is an image ImageIO can read.
    static func isImage(_ url: URL) -> Bool {
        guard url.isFileURL,
              let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
