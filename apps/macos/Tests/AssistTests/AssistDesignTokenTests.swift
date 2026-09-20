import AppKit
import SwiftUI
import XCTest
@testable import Assist

final class AssistDesignTokenTests: XCTestCase {
    /// Captions use `muted`; the design doc promises 4.5:1 on every surface
    /// they sit on, including hovered and selected rows.
    func testMutedTextKeepsReadableContrastOnEverySurface() throws {
        for scheme in [ColorScheme.light, .dark] {
            let theme = AssistTheme(colorScheme: scheme)
            let opaqueSurfaces = [
                ("background", theme.background),
                ("sidebar", theme.sidebar),
                ("card", theme.card),
                ("control", theme.control),
                ("accentSurface", theme.accentSurface),
                ("keyFill", theme.keyFill),
            ]
            var surfaces = try opaqueSurfaces.map { ($0.0, try rgba($0.1)) }
            for (name, base) in [("sidebar", theme.sidebar), ("background", theme.background)] {
                surfaces.append(("hover on \(name)", try composite(theme.hoverFill, over: base)))
                surfaces.append(("selected on \(name)", try composite(theme.selectedFill, over: base)))
            }

            let muted = try rgba(theme.muted)
            for (name, surface) in surfaces {
                let ratio = contrast(muted, surface)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(scheme) muted on \(name) is \(ratio):1")
            }
        }
    }

    func testIslandCardInkStaysReadableOnEveryTint() throws {
        let tints = AssistDesignTokens.IslandCard.textTints + [AssistDesignTokens.IslandCard.contextTint]
        for tint in tints {
            let fill = try rgba(tint.fill)
            let ink = contrast(try rgba(tint.ink), fill)
            let secondary = contrast(try composite(tint.secondaryInk, over: tint.fill), fill)
            XCTAssertGreaterThanOrEqual(ink, 7, "ink on \(String(tint.fillHex, radix: 16))")
            XCTAssertGreaterThanOrEqual(secondary, 4.5, "secondary ink on \(String(tint.fillHex, radix: 16))")
        }
    }

    /// Whatever a card shows (thumbnail, tint, or copied color), one of the
    /// selection rings keeps at least 3:1 against it.
    func testIslandSelectionRingStandsOutOverAnyCardContent() throws {
        let steps = stride(from: 0.0, through: 1.0, by: 1.0 / 7)
        for red in steps {
            for green in steps {
                for blue in steps {
                    let content = Color(red: red, green: green, blue: blue)
                    let background = try rgba(content)
                    let outer = contrast(
                        try composite(AssistDesignTokens.HistoryShelf.selectionRingOuter, over: content),
                        background
                    )
                    let inner = contrast(
                        try composite(AssistDesignTokens.HistoryShelf.selectionRingInner, over: content),
                        background
                    )
                    XCTAssertGreaterThanOrEqual(max(outer, inner), 3, "content \(red), \(green), \(blue)")
                }
            }
        }
    }

    func testCaptureShortcutHintsComeFromTheSharedDefinitions() {
        XCTAssertEqual(CaptureShortcut.idleStatus, "Hold Opt / Ctrl+Opt")
        XCTAssertEqual(CaptureShortcut.emptyHistoryHint, "Hold ⌥ to annotate  ·  ⌃⌥ for a clean screenshot")
        XCTAssertEqual(CaptureShortcut.annotate.keyNames, ["Option"])
        XCTAssertEqual(CaptureShortcut.cleanCapture.keyNames, ["Control", "Option"])
    }

    func testIslandTextTintIsStablePerClipAndUsesEveryTint() {
        let ids = (0..<30).map { _ in UUID() }
        for id in ids {
            XCTAssertEqual(AssistDesignTokens.IslandCard.textTint(for: id), AssistDesignTokens.IslandCard.textTint(for: id))
        }
        let byFirstByte = (0..<3).map { first in
            AssistDesignTokens.IslandCard.textTint(
                for: UUID(uuid: (UInt8(first), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
            )
        }
        XCTAssertEqual(byFirstByte, AssistDesignTokens.IslandCard.textTints)
    }

    /// The grain averages to zero, so each tile keeps the sampled reference
    /// color, and its strength stays close to the reference's fine grain.
    @MainActor
    func testIslandCardTilesAreCachedAndMatchTheReferenceColors() throws {
        let references: [(AssistDesignTokens.IslandCard.Tint, UInt32)] = [
            (AssistDesignTokens.IslandCard.sage, 0x98B3A3),
            (AssistDesignTokens.IslandCard.lavender, 0xA7A1BD),
            (AssistDesignTokens.IslandCard.mustard, 0xB2AC75),
            (AssistDesignTokens.IslandCard.dustyBlue, 0x96AEBF),
        ]
        for (tint, reference) in references {
            let tile = try XCTUnwrap(IslandCardTexture.tile(for: tint))
            XCTAssertTrue(IslandCardTexture.tile(for: tint) === tile, "tile is rendered once")

            // The tile's own sRGB bytes, as written; no color conversion.
            let data = try XCTUnwrap(tile.dataProvider?.data) as Data
            let bytesPerPixel = tile.bitsPerPixel / 8
            var sum = (red: 0.0, green: 0.0, blue: 0.0)
            var reds: [Double] = []
            for pixel in stride(from: 0, to: data.count, by: bytesPerPixel) {
                sum.red += Double(data[pixel]) / 255
                sum.green += Double(data[pixel + 1]) / 255
                sum.blue += Double(data[pixel + 2]) / 255
                reds.append(Double(data[pixel]) / 255)
            }
            let count = Double(reds.count)
            let expected = RGBColorComponents(hex: reference)
            let label = String(reference, radix: 16)
            XCTAssertEqual(sum.red / count, expected.red, accuracy: 1.5 / 255, label)
            XCTAssertEqual(sum.green / count, expected.green, accuracy: 1.5 / 255, label)
            XCTAssertEqual(sum.blue / count, expected.blue, accuracy: 1.5 / 255, label)

            let mean = sum.red / count
            let deviation = sqrt(reds.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / count)
            let uniformDeviation = AssistDesignTokens.IslandCard.grainAmplitude / 3.0.squareRoot()
            XCTAssertEqual(deviation, uniformDeviation, accuracy: uniformDeviation * 0.15, label)
        }
    }

    @MainActor
    func testSettingsRowTitleKeepsItsWidthBesideAFlexibleControl() {
        for trailingPriority in [0.0, 1.0, 10.0] {
            let row = SettingsRow("Volume") {
                Slider(value: .constant(0.5))
                    .frame(maxWidth: .infinity)
                    .layoutPriority(trailingPriority)
            }
            .environment(\.assistTheme, AssistTheme(colorScheme: .light))
            let size = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: 520, height: 1000))

            // A squeezed title wraps letter by letter and makes the row much taller.
            XCTAssertEqual(size.height, AssistDesignTokens.Settings.rowHeight, accuracy: 1, "priority \(trailingPriority)")
        }
    }

    private typealias RGBA = (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    private func rgba(_ color: Color) throws -> RGBA {
        let resolved = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
        return (resolved.redComponent, resolved.greenComponent, resolved.blueComponent, resolved.alphaComponent)
    }

    private func composite(_ overlay: Color, over base: Color) throws -> RGBA {
        let top = try rgba(overlay)
        let bottom = try rgba(base)
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a * top.alpha + b * (1 - top.alpha) }
        return (mix(top.red, bottom.red), mix(top.green, bottom.green), mix(top.blue, bottom.blue), 1)
    }

    private func contrast(_ a: RGBA, _ b: RGBA) -> CGFloat {
        ColorContrast.ratio(
            RGBColorComponents(red: a.red, green: a.green, blue: a.blue),
            RGBColorComponents(red: b.red, green: b.green, blue: b.blue)
        )
    }
}
