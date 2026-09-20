import AppKit
import SwiftUI

/// A tinted, grainy island card background.
struct IslandCardSurface: View {
    let tint: AssistDesignTokens.IslandCard.Tint

    var body: some View {
        Group {
            if let tile = IslandCardTexture.tile(for: tint) {
                Image(decorative: tile, scale: IslandCardTexture.scale)
                    .resizable(resizingMode: .tile)
            } else {
                tint.fill
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Each tint's grained surface, rendered once as a seamless tile and shared by
/// the SwiftUI cards and the AppKit drag preview, so drawing a card is a plain
/// tiled image rather than a blended layer.
@MainActor
enum IslandCardTexture {
    static let scale: CGFloat = 2
    private static let tilePixels = 96
    private static var tiles: [UInt32: CGImage] = [:]

    static func tile(for tint: AssistDesignTokens.IslandCard.Tint) -> CGImage? {
        if let tile = tiles[tint.fillHex] {
            return tile
        }
        guard let tile = makeTile(for: tint) else { return nil }
        tiles[tint.fillHex] = tile
        return tile
    }

    /// Fills `rect` with the tint's surface in the current AppKit context.
    static func draw(_ tint: AssistDesignTokens.IslandCard.Tint, in rect: NSRect) {
        guard let tile = tile(for: tint), let context = NSGraphicsContext.current?.cgContext else {
            NSColor(tint.fill).setFill()
            rect.fill()
            return
        }
        let tileSize = CGSize(width: CGFloat(tile.width) / scale, height: CGFloat(tile.height) / scale)
        context.saveGState()
        context.clip(to: rect)
        context.draw(tile, in: CGRect(origin: rect.origin, size: tileSize), byTiling: true)
        context.restoreGState()
    }

    /// Adds the same zero-mean noise to every tint, so a tile keeps its fill
    /// color on average and the grain matches from card to card.
    private static func makeTile(for tint: AssistDesignTokens.IslandCard.Tint) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let fill = RGBColorComponents(hex: tint.fillHex)
        let amplitude = AssistDesignTokens.IslandCard.grainAmplitude
        var noise = GrainNoise()
        var bytes = [UInt8](repeating: 0, count: tilePixels * tilePixels * 4)
        for pixel in 0..<(tilePixels * tilePixels) {
            let offset = (noise.next() * 2 - 1) * amplitude
            bytes[pixel * 4] = channel(fill.red + offset)
            bytes[pixel * 4 + 1] = channel(fill.green + offset)
            bytes[pixel * 4 + 2] = channel(fill.blue + offset)
            bytes[pixel * 4 + 3] = 255
        }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: tilePixels,
            height: tilePixels,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: tilePixels * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func channel(_ value: Double) -> UInt8 {
        UInt8((min(max(value, 0), 1) * 255).rounded())
    }
}

/// Uniform values in 0...1 from a fixed seed (xorshift64*), so the grain is
/// the same every launch.
private struct GrainNoise {
    private var state: UInt64 = 0x9E37_79B9_7F4A_7C15

    mutating func next() -> Double {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return Double((state &* 0x2545_F491_4F6C_DD1D) >> 11) / Double(1 << 53)
    }
}
