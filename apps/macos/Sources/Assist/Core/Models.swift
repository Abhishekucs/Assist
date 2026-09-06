import Foundation
import CoreGraphics

struct CaptureItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let imagePath: String
    let thumbnailPath: String
    var context: ScreenshotContext

    var captureDirectoryURL: URL? {
        let imageURL = URL(fileURLWithPath: imagePath).standardizedFileURL
        let directoryURL = imageURL.deletingLastPathComponent()
        guard imageURL.lastPathComponent == "screenshot.png",
              directoryURL.lastPathComponent.caseInsensitiveCompare(id.uuidString) == .orderedSame else {
            return nil
        }

        return directoryURL
    }

    var contextFileURL: URL? {
        captureDirectoryURL?.appendingPathComponent("context.md", isDirectory: false)
    }

    var hasVoiceContext: Bool {
        context.dictation != nil
    }
}

struct TextClipItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let text: String

    var preview: String {
        let collapsedWhitespace = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return String(collapsedWhitespace.prefix(140))
    }

    var colorCode: ClipboardColorCode? {
        ClipboardColorCode(text)
    }
}

struct RGBColorComponents: Equatable, Sendable {
    static let black = RGBColorComponents(red: 0, green: 0, blue: 0)
    static let white = RGBColorComponents(red: 1, green: 1, blue: 1)

    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xff) / 255
        green = Double((hex >> 8) & 0xff) / 255
        blue = Double(hex & 0xff) / 255
    }
}

struct ClipboardColorCode: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let displayValue: String

    /// Chooses black or white using WCAG contrast after translucent colors are composited over
    /// the actual card surface.
    func usesDarkForeground(over surface: RGBColorComponents) -> Bool {
        let composited = RGBColorComponents(
            red: red * alpha + surface.red * (1 - alpha),
            green: green * alpha + surface.green * (1 - alpha),
            blue: blue * alpha + surface.blue * (1 - alpha)
        )
        let luminance = Self.relativeLuminance(of: composited)
        let blackContrast = (luminance + 0.05) / 0.05
        let whiteContrast = 1.05 / (luminance + 0.05)
        return blackContrast >= whiteContrast
    }

    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits: Substring

        if trimmed.hasPrefix("#") {
            digits = trimmed.dropFirst()
        } else if trimmed.lowercased().hasPrefix("0x") {
            digits = trimmed.dropFirst(2)
        } else {
            return nil
        }

        guard [3, 4, 6, 8].contains(digits.count),
              digits.allSatisfy(\.isHexDigit) else {
            return nil
        }

        let expanded: String
        if digits.count <= 4 {
            expanded = digits.map { "\($0)\($0)" }.joined()
        } else {
            expanded = String(digits)
        }

        guard let value = UInt64(expanded, radix: 16) else { return nil }
        let includesAlpha = expanded.count == 8
        let shift = includesAlpha ? 8 : 0

        red = Double((value >> UInt64(16 + shift)) & 0xff) / 255
        green = Double((value >> UInt64(8 + shift)) & 0xff) / 255
        blue = Double((value >> UInt64(shift)) & 0xff) / 255
        alpha = includesAlpha ? Double(value & 0xff) / 255 : 1
        displayValue = "#" + expanded.uppercased()
    }

    private static func relativeLuminance(of color: RGBColorComponents) -> Double {
        let red = linearizedSRGB(color.red)
        let green = linearizedSRGB(color.green)
        let blue = linearizedSRGB(color.blue)
        return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    private static func linearizedSRGB(_ component: Double) -> Double {
        let component = min(max(component, 0), 1)
        if component <= 0.04045 {
            return component / 12.92
        }
        return pow((component + 0.055) / 1.055, 2.4)
    }
}

enum ClipboardHistoryItem: Identifiable, Equatable {
    case screenshot(CaptureItem)
    case text(TextClipItem)

    var id: UUID {
        switch self {
        case let .screenshot(item):
            item.id
        case let .text(item):
            item.id
        }
    }

    var createdAt: Date {
        switch self {
        case let .screenshot(item):
            item.createdAt
        case let .text(item):
            item.createdAt
        }
    }
}

enum ClipboardHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case images

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .text:
            "Text"
        case .images:
            "Images"
        }
    }

    func includes(_ item: ClipboardHistoryItem) -> Bool {
        switch (self, item) {
        case (.all, _), (.text, .text), (.images, .screenshot):
            true
        default:
            false
        }
    }
}

struct CopyFeedback: Equatable {
    enum Kind: Equatable {
        case success
        case warning
    }

    let id: UUID
    let badge: String
    let preview: String
    var kind: Kind = .success
}

enum CaptureIssueAction: Equatable {
    case requestScreenRecordingPermission
    case openScreenRecordingSettings
    case openAccessibilitySettings
    case openInputMonitoringSettings
}

struct CaptureIssue: Equatable {
    let title: String
    let message: String
    let detail: String?
    let primaryActionTitle: String
    let primaryAction: CaptureIssueAction
    let secondaryActionTitle: String?
    let secondaryAction: CaptureIssueAction?

    static func screenRecording(detail: String?) -> CaptureIssue {
        CaptureIssue(
            title: "Screen Recording needed",
            message: "Assist needs Screen & System Audio Recording permission before it can capture the app or screen under your pointer.",
            detail: detail,
            primaryActionTitle: "Request Permission",
            primaryAction: .requestScreenRecordingPermission,
            secondaryActionTitle: "Open Settings",
            secondaryAction: .openScreenRecordingSettings
        )
    }

    static func inputMonitoring(detail: String?) -> CaptureIssue {
        CaptureIssue(
            title: "Input permission needed",
            message: "Assist needs Accessibility or Input Monitoring permission to detect the global Option and Control + Option shortcuts.",
            detail: detail,
            primaryActionTitle: "Open Accessibility",
            primaryAction: .openAccessibilitySettings,
            secondaryActionTitle: "Input Monitoring",
            secondaryAction: .openInputMonitoringSettings
        )
    }

    static func captureFailed(detail: String?) -> CaptureIssue {
        CaptureIssue(
            title: "Capture failed",
            message: "Assist could not save the screenshot. The details below came from macOS.",
            detail: detail,
            primaryActionTitle: "Request Permission",
            primaryAction: .requestScreenRecordingPermission,
            secondaryActionTitle: "Open Settings",
            secondaryAction: .openScreenRecordingSettings
        )
    }

    static func screenRecordingNeedsSettings(detail: String?) -> CaptureIssue {
        CaptureIssue(
            title: "Screen Recording needed",
            message: "Turn on Assist in Screen & System Audio Recording, then quit and reopen Assist.",
            detail: detail,
            primaryActionTitle: "Open Settings",
            primaryAction: .openScreenRecordingSettings,
            secondaryActionTitle: nil,
            secondaryAction: nil
        )
    }
}

struct ScreenshotContext: Codable, Equatable {
    var summary: String
    var visibleText: [String]
    var appsDetected: [String]
    var uiElements: [String]
    var entities: [String]
    var sensitiveDataWarnings: [String]
    var dictation: DictationContext? = nil

    static let saved = ScreenshotContext(
        summary: "Screenshot saved.",
        visibleText: [],
        appsDetected: [],
        uiElements: [],
        entities: [],
        sensitiveDataWarnings: [],
        dictation: nil
    )
}

enum DictationStatus: String, Codable, Equatable, Sendable {
    case transcribing
    case ready
    case noSpeech
    case failed
}

struct DictationContext: Codable, Equatable, Sendable {
    var status: DictationStatus
    var transcript: String
    var language: String
    var modelIdentifier: String
    var modelRevision: String
    var errorDetails: String?
}

struct Stroke: Codable, Equatable {
    var points: [CGPoint]
    var colorHex: String
    var width: CGFloat
}

struct CapturedScreen {
    let image: CGImage
    let screenFrame: CGRect
    let pointSize: CGSize
    let displayID: CGDirectDisplayID
}

enum AppError: LocalizedError {
    case screenCaptureUnavailable
    case screenRecordingPermissionRequired
    case imageEncodingFailed
    case eventTapUnavailable

    var errorDescription: String? {
        switch self {
        case .screenCaptureUnavailable:
            "Unable to capture the current display."
        case .screenRecordingPermissionRequired:
            "Screen Recording permission is not enabled for \(AppIdentity.name)."
        case .imageEncodingFailed:
            "Unable to encode the annotated screenshot."
        case .eventTapUnavailable:
            "Unable to listen for global shortcuts. Enable Accessibility/Input Monitoring for \(AppIdentity.name)."
        }
    }
}
