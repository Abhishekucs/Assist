import AppKit
import XCTest
@testable import Assist

final class AnnotationTrailTests: XCTestCase {
    func testTrailExpiresVisualSamplesAfterTwoSecondsWithoutLosingSourceProgress() {
        let first = CGPoint(x: 10, y: 10)
        let second = CGPoint(x: 20, y: 20)
        let third = CGPoint(x: 30, y: 30)
        let fourth = CGPoint(x: 40, y: 40)
        var trail = AnnotationTrailState()

        trail.begin(points: [first], at: 0)
        trail.update(points: [first, second, third], at: 1)
        trail.removeExpired(at: 2.1, lifetime: AnnotationOverlayView.trailLifetime)

        XCTAssertEqual(trail.samples.map(\.point), [second, third])
        XCTAssertEqual(trail.sourcePointCount, 3)

        trail.update(points: [first, second, third, fourth], at: 2.2)

        XCTAssertEqual(trail.samples.map(\.point), [second, third, fourth])
        XCTAssertEqual(trail.sourcePointCount, 4)
    }

    func testTrailVisibilityFallsSmoothlyToZero() throws {
        var trail = AnnotationTrailState()
        trail.begin(points: [CGPoint(x: 10, y: 10)], at: 10)
        let sample = try XCTUnwrap(trail.samples.first)

        XCTAssertEqual(
            trail.visibility(of: sample, at: 10, lifetime: 2),
            1,
            accuracy: 0.001
        )
        XCTAssertEqual(
            trail.visibility(of: sample, at: 11, lifetime: 2),
            0.25,
            accuracy: 0.001
        )
        XCTAssertEqual(
            trail.visibility(of: sample, at: 12, lifetime: 2),
            0,
            accuracy: 0.001
        )
    }

    func testBeginningNewAnnotationResetsPriorVisualTrail() {
        var trail = AnnotationTrailState()
        trail.begin(
            points: [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)],
            at: 0
        )

        let newStart = CGPoint(x: 100, y: 100)
        trail.begin(points: [newStart], at: 5)

        XCTAssertEqual(trail.samples, [AnnotationTrailSample(point: newStart, timestamp: 5)])
        XCTAssertEqual(trail.sourcePointCount, 1)
    }

    @MainActor
    func testSavedCompositeRetainsTheCompleteAnnotationPath() throws {
        let width = 100
        let height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        )
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let baseImage = try XCTUnwrap(context.makeImage())
        let captured = CapturedScreen(
            image: baseImage,
            screenFrame: CGRect(x: 0, y: 0, width: width, height: height),
            pointSize: CGSize(width: width, height: height),
            displayID: 0
        )
        let stroke = Stroke(
            points: [
                CGPoint(x: 8, y: 8),
                CGPoint(x: 50, y: 50),
                CGPoint(x: 92, y: 92)
            ],
            colorHex: "#FF3B30",
            width: 6
        )

        let composited = try CaptureService().composite(captured: captured, stroke: stroke)
        let tiffData = try XCTUnwrap(composited.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        var redPixelXs: [Int] = []

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                if color.redComponent > 0.8,
                   color.greenComponent < 0.5,
                   color.blueComponent < 0.5 {
                    redPixelXs.append(x)
                }
            }
        }

        XCTAssertGreaterThan(redPixelXs.count, 300)
        XCTAssertLessThanOrEqual(try XCTUnwrap(redPixelXs.min()), 10)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(redPixelXs.max()), 90)
    }
}
