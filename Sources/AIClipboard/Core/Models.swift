import Foundation
import CoreGraphics

struct CaptureItem: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let imagePath: String
    let thumbnailPath: String
    var context: ScreenshotContext
}

struct ScreenshotContext: Codable, Equatable {
    var summary: String
    var visibleText: [String]
    var appsDetected: [String]
    var uiElements: [String]
    var entities: [String]
    var possibleUserIntent: String
    var agentInstructions: [String]
    var sensitiveDataWarnings: [String]

    static let pending = ScreenshotContext(
        summary: "Analyzing screenshot...",
        visibleText: [],
        appsDetected: [],
        uiElements: [],
        entities: [],
        possibleUserIntent: "Pending",
        agentInstructions: [],
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
    case imageEncodingFailed
    case eventTapUnavailable

    var errorDescription: String? {
        switch self {
        case .screenCaptureUnavailable:
            "Unable to capture the current display."
        case .imageEncodingFailed:
            "Unable to encode the annotated screenshot."
        case .eventTapUnavailable:
            "Unable to listen for the Control key. Enable Accessibility/Input Monitoring for global shortcuts."
        }
    }
}
