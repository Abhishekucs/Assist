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
            let selection = contrast(
                try composite(tint.ink.opacity(AssistDesignTokens.IslandCard.selectionInkOpacity), over: tint.fill),
                fill
            )
            XCTAssertGreaterThanOrEqual(ink, 7, "ink on \(String(tint.fillHex, radix: 16))")
            XCTAssertGreaterThanOrEqual(secondary, 4.5, "secondary ink on \(String(tint.fillHex, radix: 16))")
            XCTAssertGreaterThanOrEqual(selection, 3, "selection stroke on \(String(tint.fillHex, radix: 16))")
        }
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

    @MainActor
    func testIslandCardGrainTextureIsGenerated() throws {
        let texture = try XCTUnwrap(IslandCardGrain.texture)
        XCTAssertEqual(texture.width, texture.height)
        XCTAssertGreaterThan(texture.width, 0)
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
        func luminance(_ c: RGBA) -> CGFloat {
            func channel(_ v: CGFloat) -> CGFloat {
                v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue)
        }
        let (lighter, darker) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (lighter + 0.05) / (darker + 0.05)
    }
}
