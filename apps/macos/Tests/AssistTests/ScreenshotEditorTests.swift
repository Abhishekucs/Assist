import AppKit
import XCTest
@testable import Assist

final class ScreenshotEditorTests: XCTestCase {
    func testEntryWindowDismissesOnlyBeforeTheFirstHover() {
        var presence = ScreenshotEditorPresence()

        XCTAssertTrue(presence.shouldDismissWhenEntryWindowExpires())
        XCTAssertFalse(presence.shouldDismissWhenPointerExits())

        presence.pointerEntered()

        XCTAssertFalse(presence.shouldDismissWhenEntryWindowExpires())
        XCTAssertTrue(presence.shouldDismissWhenPointerExits())
    }

    func testPointerExitDismissesTheEditorRegardlessOfDraftState() {
        var presence = ScreenshotEditorPresence()
        presence.pointerEntered()

        XCTAssertTrue(presence.shouldDismissWhenPointerExits())
    }

    func testPointerExitCannotDismissAnInProgressSave() {
        var presence = ScreenshotEditorPresence()
        presence.pointerEntered()

        XCTAssertFalse(presence.shouldDismissWhenPointerExits(isSaving: true))
        XCTAssertTrue(presence.shouldDismissWhenPointerExits(isSaving: false))
    }

    func testExpandedFrameGrowsAndRemainsLandscape() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let island = CGRect(x: 826, y: 1050, width: 268, height: 30)

        let collapsed = ScreenshotEditorMetrics.frame(below: island, on: screen)
        let expanded = ScreenshotEditorMetrics.frame(
            below: island,
            on: screen,
            expanded: true
        )

        XCTAssertGreaterThan(expanded.width, collapsed.width)
        XCTAssertGreaterThan(expanded.height, collapsed.height)
        XCTAssertEqual(expanded.size, ScreenshotEditorMetrics.preferredExpandedSize)
        XCTAssertGreaterThan(expanded.width, expanded.height)

        XCTAssertEqual(island.minY - expanded.maxY, 8)
        XCTAssertEqual(expanded.midX, island.midX)
    }

    func testExpandedFrameNeverShrinksBelowTheCompactCard() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let island = CGRect(x: 586, y: 870, width: 268, height: 30)

        let expanded = ScreenshotEditorMetrics.frame(
            below: island,
            on: screen,
            expanded: true
        )

        XCTAssertGreaterThan(expanded.width, ScreenshotEditorMetrics.preferredSize.width)
        XCTAssertGreaterThan(expanded.height, ScreenshotEditorMetrics.preferredSize.height)
        XCTAssertEqual(
            expanded.width / expanded.height,
            ScreenshotEditorMetrics.preferredExpandedSize.width
                / ScreenshotEditorMetrics.preferredExpandedSize.height,
            accuracy: 0.02
        )
    }

    func testExpandedFrameStaysOnShortScreens() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 300)
        let island = CGRect(x: 586, y: 270, width: 268, height: 30)

        let expanded = ScreenshotEditorMetrics.frame(
            below: island,
            on: screen,
            expanded: true
        )

        XCTAssertGreaterThanOrEqual(expanded.minY, screen.minY + ScreenshotEditorMetrics.screenMargin)
        XCTAssertLessThanOrEqual(expanded.maxY, island.minY - ScreenshotEditorMetrics.islandGap)
        XCTAssertGreaterThanOrEqual(expanded.minX, screen.minX + ScreenshotEditorMetrics.screenMargin)
        XCTAssertLessThanOrEqual(expanded.maxX, screen.maxX - ScreenshotEditorMetrics.screenMargin)
        XCTAssertEqual(
            expanded.width / expanded.height,
            ScreenshotEditorMetrics.preferredExpandedSize.width
                / ScreenshotEditorMetrics.preferredExpandedSize.height,
            accuracy: 0.02
        )
    }

    func testEditorFrameIsCenteredEightPointsBelowTheIsland() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let island = CGRect(x: 586, y: 870, width: 268, height: 30)

        let frame = ScreenshotEditorMetrics.frame(below: island, on: screen)

        XCTAssertEqual(frame.size, ScreenshotEditorMetrics.preferredSize)
        XCTAssertEqual(island.minY - frame.maxY, 8)
        XCTAssertEqual(frame.midX, island.midX)
    }

    func testCompactEditorKeepsItsLandscapeOrientation() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let island = CGRect(x: 586, y: 870, width: 268, height: 30)

        let frame = ScreenshotEditorMetrics.frame(below: island, on: screen)

        XCTAssertEqual(frame.size, ScreenshotEditorMetrics.preferredSize)
        XCTAssertGreaterThan(frame.width, frame.height)
        XCTAssertEqual(ScreenshotEditorMetrics.canvasTopInset, ScreenshotEditorMetrics.canvasInset)
    }

    func testCompactPreviewMatchesWidescreenCaptureAspect() {
        let preferred = ScreenshotEditorMetrics.preferredSize
        let previewHeight = ScreenshotEditorMetrics.previewAreaHeight(
            forCardHeight: preferred.height
        )
        let contentWidth = preferred.width - ScreenshotEditorMetrics.canvasInset * 2
        let contentHeight = previewHeight
            - ScreenshotEditorMetrics.headerHeight
            - ScreenshotEditorMetrics.canvasTopInset
            - ScreenshotEditorMetrics.canvasInset

        XCTAssertEqual(contentWidth / contentHeight, 16.0 / 9.0, accuracy: 0.002)
    }

    func testEditorReservesEightyPercentForPreviewAndTwentyPercentForTools() {
        let height = ScreenshotEditorMetrics.preferredSize.height

        XCTAssertEqual(
            ScreenshotEditorMetrics.previewAreaHeight(forCardHeight: height) / height,
            0.8,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ScreenshotEditorMetrics.controlsAreaHeight(forCardHeight: height) / height,
            0.2,
            accuracy: 0.0001
        )
    }

    func testCompactToolShelfFitsWithoutSquashingControls() {
        let toolShelfHeight = ScreenshotEditorMetrics.controlsAreaHeight(
            forCardHeight: ScreenshotEditorMetrics.preferredSize.height
        )
        let layout = AssistDesignTokens.ScreenshotEditor.Layout.self
        let requiredHeight =
            layout.controlsTopInset
            + layout.primaryRowHeight
            + layout.controlsRowSpacing
            + layout.optionsRowHeight
            + layout.controlsBottomInset

        XCTAssertEqual(requiredHeight, toolShelfHeight, accuracy: 0.0001)
        XCTAssertEqual(layout.controlsRowSpacing, AssistDesignTokens.Spacing.small)
        XCTAssertGreaterThan(layout.controlsBottomInset, layout.controlsTopInset)
        XCTAssertGreaterThanOrEqual(
            layout.toolChipHeight,
            AssistDesignTokens.Control.regularHeight
        )
        XCTAssertGreaterThanOrEqual(
            layout.chipHeight,
            AssistDesignTokens.Control.compactHeight
        )
        XCTAssertEqual(layout.saveHeight, layout.toolChipHeight)
    }

    func testEditorFrameShrinksProportionallyOnShortScreens() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 300)
        let island = CGRect(x: 586, y: 270, width: 268, height: 30)
        let preferred = ScreenshotEditorMetrics.preferredSize

        let frame = ScreenshotEditorMetrics.frame(below: island, on: screen)

        XCTAssertLessThan(frame.height, preferred.height)
        XCTAssertGreaterThanOrEqual(frame.minY, screen.minY + ScreenshotEditorMetrics.screenMargin)
        XCTAssertEqual(frame.width / frame.height, preferred.width / preferred.height, accuracy: 0.02)
    }

    func testFixedAspectCropKeepsPixelRatioInsideTheImage() {
        // A 2:1 image: a square crop must be half as wide as it is tall in normalized space.
        let square = ScreenshotCropAspect.square.cropRect(
            from: CGPoint(x: 0.1, y: 0.1),
            to: CGPoint(x: 0.9, y: 0.9),
            imageAspectRatio: 2
        )
        XCTAssertEqual(square.width, 0.4, accuracy: 0.0001)
        XCTAssertEqual(square.height, 0.8, accuracy: 0.0001)
        XCTAssertEqual(square.origin, CGPoint(x: 0.1, y: 0.1))

        // Dragging up-left anchors at the start point and never leaves the unit square.
        let wide = ScreenshotCropAspect.sixteenByNine.cropRect(
            from: CGPoint(x: 0.9, y: 0.2),
            to: CGPoint(x: 0.1, y: 0.9),
            imageAspectRatio: 1
        )
        XCTAssertEqual(wide.maxX, 0.9, accuracy: 0.0001)
        XCTAssertEqual(wide.minY, 0.2, accuracy: 0.0001)
        XCTAssertEqual(wide.width / wide.height, 16.0 / 9.0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(wide.minX, 0)
        XCTAssertLessThanOrEqual(wide.maxY, 1)

        let free = ScreenshotCropAspect.free.cropRect(
            from: CGPoint(x: 0.2, y: 0.3),
            to: CGPoint(x: 0.7, y: 0.4),
            imageAspectRatio: 1.5
        )
        XCTAssertEqual(free.minX, 0.2, accuracy: 0.0001)
        XCTAssertEqual(free.minY, 0.3, accuracy: 0.0001)
        XCTAssertEqual(free.width, 0.5, accuracy: 0.0001)
        XCTAssertEqual(free.height, 0.1, accuracy: 0.0001)
    }

    func testCropRendererUsesNormalizedTopLeftCoordinates() throws {
        let image = try makeSplitImage(width: 8, height: 6)
        var draft = ScreenshotEditDraft()
        draft.cropRect = CGRect(x: 0.25, y: 1.0 / 6.0, width: 0.5, height: 0.5)

        let rendered = try ScreenshotEditRenderer().render(image: image, draft: draft)
        let bitmap = try bitmap(from: rendered)

        XCTAssertEqual(bitmap.pixelsWide, 4)
        XCTAssertEqual(bitmap.pixelsHigh, 3)
        XCTAssertEqual(rendered.size.width, 4, accuracy: 0.001)
        XCTAssertEqual(rendered.size.height, 3, accuracy: 0.001)
    }

    func testCroppingTheRightHalfKeepsOnlyTheWhiteSide() throws {
        let image = try makeSplitImage(width: 8, height: 6)
        var draft = ScreenshotEditDraft()
        draft.cropRect = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)

        let rendered = try ScreenshotEditRenderer().render(image: image, draft: draft)
        let bitmap = try bitmap(from: rendered)
        let sample = try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB))

        XCTAssertEqual(bitmap.pixelsWide, 4)
        XCTAssertEqual(sample.redComponent, 1, accuracy: 0.02)
    }

    func testBlurRendererChangesOnlyThePaintedRegion() throws {
        let image = try makeSplitImage(width: 64, height: 64)
        var draft = ScreenshotEditDraft()
        draft.blurStrokes = [
            ScreenshotBlurStroke(
                points: [CGPoint(x: 0.5, y: 0.25), CGPoint(x: 0.5, y: 0.75)],
                diameterFraction: 0.3,
                blurRadiusFraction: 0.1
            )
        ]

        let rendered = try ScreenshotEditRenderer().render(image: image, draft: draft)
        let bitmap = try bitmap(from: rendered)
        let untouched = try XCTUnwrap(bitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.deviceRGB))
        let blurred = try XCTUnwrap(bitmap.colorAt(x: 32, y: 32)?.usingColorSpace(.deviceRGB))

        XCTAssertEqual(untouched.redComponent, 0, accuracy: 0.02)
        XCTAssertGreaterThan(blurred.redComponent, 0.08)
        XCTAssertLessThan(blurred.redComponent, 0.92)
    }

    func testStandardStyleLeavesTheBitmapUntouched() throws {
        let image = try makeSolidImage(width: 40, height: 30)
        let rendered = try ScreenshotEditRenderer().render(image: image, draft: ScreenshotEditDraft())
        let bitmap = try bitmap(from: rendered)

        XCTAssertEqual(bitmap.pixelsWide, 40)
        XCTAssertEqual(bitmap.pixelsHigh, 30)
        XCTAssertFalse(ScreenshotEditDraft().hasEdits)
    }

    func testFramedStyleAddsTransparentPaddingAndRoundedCorners() throws {
        let image = try makeSolidImage(width: 40, height: 40)
        var draft = ScreenshotEditDraft()
        draft.style.paddingFraction = 0.25
        draft.style.cornerRadiusFraction = 0.08
        XCTAssertTrue(draft.hasEdits)

        let rendered = try ScreenshotEditRenderer().render(image: image, draft: draft)
        let bitmap = try bitmap(from: rendered)

        XCTAssertEqual(bitmap.pixelsWide, 60)
        XCTAssertEqual(bitmap.pixelsHigh, 60)
        XCTAssertEqual(rendered.size.width, 60, accuracy: 0.001)

        let padding = try XCTUnwrap(bitmap.colorAt(x: 2, y: 2))
        let corner = try XCTUnwrap(bitmap.colorAt(x: 10, y: 10))
        let center = try XCTUnwrap(bitmap.colorAt(x: 30, y: 30)?.usingColorSpace(.deviceRGB))

        XCTAssertEqual(padding.alphaComponent, 0, accuracy: 0.02)
        XCTAssertLessThan(corner.alphaComponent, 0.5)
        XCTAssertEqual(center.alphaComponent, 1, accuracy: 0.01)
        XCTAssertEqual(center.redComponent, 1, accuracy: 0.02)
    }

    func testGradientBackdropFillsThePadding() throws {
        let image = try makeSolidImage(width: 40, height: 40)
        let midnight = try XCTUnwrap(ScreenshotGradientPreset.all.first { $0.id == "midnight" })
        var draft = ScreenshotEditDraft()
        draft.style.select(.gradient(midnight))

        // The first backdrop pick frames the shot so a single click looks finished.
        XCTAssertGreaterThan(draft.style.paddingFraction, 0)
        XCTAssertGreaterThan(draft.style.cornerRadiusFraction, 0)
        XCTAssertTrue(draft.style.showsShadow)

        let rendered = try ScreenshotEditRenderer().render(image: image, draft: draft)
        let bitmap = try bitmap(from: rendered)
        let padding = try XCTUnwrap(bitmap.colorAt(x: 1, y: 1)?.usingColorSpace(.deviceRGB))

        XCTAssertGreaterThan(bitmap.pixelsWide, 40)
        XCTAssertEqual(padding.alphaComponent, 1, accuracy: 0.01)
        XCTAssertLessThan(padding.redComponent, 0.5)
    }

    func testSelectingNoBackdropKeepsExistingFraming() {
        var style = ScreenshotFrameStyle.standard
        style.select(.gradient(ScreenshotGradientPreset.all[0]))
        let framed = style

        style.select(.none)

        XCTAssertEqual(style.background, .none)
        XCTAssertEqual(style.paddingFraction, framed.paddingFraction)
        XCTAssertEqual(style.cornerRadiusFraction, framed.cornerRadiusFraction)
        XCTAssertEqual(style.showsShadow, framed.showsShadow)
    }

    private func makeSplitImage(width: Int, height: Int) throws -> NSImage {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        let cgImage = try XCTUnwrap(context.makeImage())
        return NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
    }

    private func makeSolidImage(width: Int, height: Int) throws -> NSImage {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = try XCTUnwrap(context.makeImage())
        return NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
    }

    private func bitmap(from image: NSImage) throws -> NSBitmapImageRep {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        let cgImage = try XCTUnwrap(
            image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
        )
        return NSBitmapImageRep(cgImage: cgImage)
    }
}
