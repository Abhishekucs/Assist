import AppKit
@preconcurrency import ScreenCaptureKit

@MainActor
struct CaptureService: Sendable {
    func capture(screen: NSScreen) async throws -> CapturedScreen {
        let hasPreflightAccess = CGPreflightScreenCaptureAccess()
        DebugLogger.log("capture.request", [
            "displayID": "\(screen.displayID)",
            "screenFrame": DebugLogger.describe(screen.frame),
            "visibleFrame": DebugLogger.describe(screen.visibleFrame),
            "scale": "\(screen.backingScaleFactor)",
            "preflight": "\(hasPreflightAccess)"
        ])

        do {
            let captured: CapturedScreen
            if #available(macOS 14.0, *) {
                guard hasPreflightAccess else {
                    DebugLogger.log("capture.screen-recording.missing", [
                        "bundle": Bundle.main.bundleIdentifier ?? "unknown",
                        "executable": Bundle.main.executablePath ?? "unknown"
                    ])
                    throw AppError.screenRecordingPermissionRequired
                }
                captured = try await captureWithScreenCaptureKit(screen: screen)
            } else {
                guard requestScreenCaptureAccessIfNeeded(hasPreflightAccess: hasPreflightAccess) else {
                    throw AppError.screenRecordingPermissionRequired
                }
                captured = try captureWithCoreGraphics(screen: screen)
            }

            DebugLogger.log("capture.success", [
                "displayID": "\(captured.displayID)",
                "imageSize": "\(captured.image.width)x\(captured.image.height)"
            ])
            return captured
        } catch {
            DebugLogger.log("capture.error", Self.errorFields(error))
            throw error
        }
    }

    @discardableResult
    private func requestScreenCaptureAccessIfNeeded(hasPreflightAccess: Bool) -> Bool {
        guard !hasPreflightAccess else { return true }

        DebugLogger.log("capture.screen-recording.request", [
            "bundle": Bundle.main.bundleIdentifier ?? "unknown",
            "executable": Bundle.main.executablePath ?? "unknown"
        ])

        let requestResult = CGRequestScreenCaptureAccess()
        let postflight = CGPreflightScreenCaptureAccess()
        DebugLogger.log("capture.screen-recording.request.result", [
            "requestResult": "\(requestResult)",
            "postflight": "\(postflight)"
        ])

        return postflight
    }

    private func captureWithCoreGraphics(screen: NSScreen) throws -> CapturedScreen {
        let displayID = screen.displayID
        DebugLogger.log("capture.coregraphics.start", ["displayID": "\(displayID)"])

        guard let image = CGDisplayCreateImage(displayID) else {
            DebugLogger.log("capture.coregraphics.error", ["displayID": "\(displayID)"])
            throw AppError.screenCaptureUnavailable
        }

        DebugLogger.log("capture.coregraphics.success", [
            "displayID": "\(displayID)",
            "imageSize": "\(image.width)x\(image.height)"
        ])

        return CapturedScreen(
            image: image,
            screenFrame: screen.frame,
            pointSize: screen.frame.size,
            displayID: displayID
        )
    }

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKit(screen: NSScreen) async throws -> CapturedScreen {
        let displayID = screen.displayID
        DebugLogger.log("capture.sck.display.start", ["displayID": "\(displayID)"])
        return try await captureWithScreenCaptureKitDisplayFilter(screen: screen)
    }

    @available(macOS 14.0, *)
    private func captureWithScreenCaptureKitDisplayFilter(screen: NSScreen) async throws -> CapturedScreen {
        let displayID = screen.displayID
        let content = try await SCShareableContent.current

        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            DebugLogger.log("capture.sck.display.missing", [
                "displayID": "\(displayID)",
                "availableDisplays": content.displays.map { "\($0.displayID)" }.joined(separator: ",")
            ])
            throw AppError.screenCaptureUnavailable
        }

        let currentProcessID = NSRunningApplication.current.processIdentifier
        let excludedApplications = content.applications.filter { $0.processID == currentProcessID }
        let filter: SCContentFilter

        if excludedApplications.isEmpty {
            filter = SCContentFilter(display: display, excludingWindows: [])
        } else {
            filter = SCContentFilter(
                display: display,
                excludingApplications: excludedApplications,
                exceptingWindows: []
            )
        }

        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }

        let configuration = SCStreamConfiguration()
        configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
        configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
        configuration.showsCursor = false
        configuration.queueDepth = 1
        configuration.capturesAudio = false

        let image = try await ScreenCaptureKitScreenshot.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        DebugLogger.log("capture.sck.display.success", [
            "displayID": "\(displayID)",
            "imageSize": "\(image.width)x\(image.height)",
            "configuredSize": "\(configuration.width)x\(configuration.height)",
            "excludedCurrentApp": "\(excludedApplications.isEmpty == false)",
            "filterContentRect": DebugLogger.describe(filter.contentRect),
            "filterScale": "\(filter.pointPixelScale)"
        ])

        return CapturedScreen(
            image: image,
            screenFrame: screen.frame,
            pointSize: screen.frame.size,
            displayID: displayID
        )
    }

    #if ASSIST_ENABLE_DEPRECATED_CAPTURE_FALLBACK
    private func captureWithCoreGraphicsWindowList(screen: NSScreen) throws -> CapturedScreen {
        let displayID = screen.displayID
        let displayBounds = CGDisplayBounds(displayID)
        DebugLogger.log("capture.cg-window-list.start", [
            "displayID": "\(displayID)",
            "displayBounds": DebugLogger.describe(displayBounds)
        ])

        let imageOptions: CGWindowImageOption = [
            .bestResolution,
            .boundsIgnoreFraming
        ]

        guard let image = CGWindowListCreateImage(
            displayBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            imageOptions
        ) else {
            DebugLogger.log("capture.cg-window-list.error", ["displayID": "\(displayID)"])
            throw AppError.screenCaptureUnavailable
        }

        DebugLogger.log("capture.cg-window-list.success", [
            "displayID": "\(displayID)",
            "imageSize": "\(image.width)x\(image.height)"
        ])

        return CapturedScreen(
            image: image,
            screenFrame: screen.frame,
            pointSize: screen.frame.size,
            displayID: displayID
        )
    }
    #endif

    func image(from captured: CapturedScreen) -> NSImage {
        NSImage(cgImage: captured.image, size: captured.pointSize)
    }

    func composite(captured: CapturedScreen, stroke: Stroke) throws -> NSImage {
        let image = NSImage(size: captured.pointSize)
        let rect = CGRect(origin: .zero, size: captured.pointSize)
        let baseImage = NSImage(cgImage: captured.image, size: captured.pointSize)

        image.lockFocus()
        baseImage.draw(
            in: rect,
            from: NSRect.zero,
            operation: NSCompositingOperation.copy,
            fraction: 1
        )
        draw(stroke: stroke, in: captured.pointSize)
        image.unlockFocus()

        return image
    }

    private func draw(stroke: Stroke, in size: CGSize) {
        let color = NSColor(hex: stroke.colorHex) ?? .systemRed
        color.setStroke()
        color.setFill()
        let points = stroke.points.map { CGPoint(x: $0.x, y: size.height - $0.y) }

        if points.count <= 1, let point = points.first {
            let radius = max(stroke.width, 8)
            let dotRect = CGRect(
                x: point.x - radius / 2,
                y: point.y - radius / 2,
                width: radius,
                height: radius
            )
            NSBezierPath(ovalIn: dotRect).fill()
            return
        }

        let path = NSBezierPath()
        path.lineWidth = stroke.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() {
                path.line(to: point)
            }
        }

        path.stroke()

        if let first = points.first {
            let dotSize: CGFloat = 10
            NSBezierPath(ovalIn: CGRect(
                x: first.x - dotSize / 2,
                y: first.y - dotSize / 2,
                width: dotSize,
                height: dotSize
            )).fill()
        }
    }

    private static func errorFields(_ error: Error) -> [String: String] {
        let nsError = error as NSError
        return [
            "domain": nsError.domain,
            "code": "\(nsError.code)",
            "description": nsError.localizedDescription
        ]
    }
}

@available(macOS 14.0, *)
private enum ScreenCaptureKitScreenshot {
    // ScreenCaptureKit calls this completion from replayd's XPC queue, not the main actor.
    nonisolated static func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? AppError.screenCaptureUnavailable)
                }
            }
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = deviceDescription[key] as? NSNumber {
            return number.uint32Value
        }

        return CGMainDisplayID()
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else {
            return nil
        }

        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}
