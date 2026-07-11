import Foundation
import CoreGraphics

struct CaptureItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let imagePath: String
    let thumbnailPath: String
    var context: ScreenshotContext
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

struct CopyFeedback: Equatable {
    let id: UUID
    let badge: String
    let preview: String
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

    static let saved = ScreenshotContext(
        summary: "Screenshot saved.",
        visibleText: [],
        appsDetected: [],
        uiElements: [],
        entities: [],
        sensitiveDataWarnings: []
    )
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
