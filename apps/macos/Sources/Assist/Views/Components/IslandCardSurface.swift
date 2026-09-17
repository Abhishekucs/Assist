import AppKit
import SwiftUI

private typealias CardTokens = AssistDesignTokens.IslandCard

/// A tinted island card background with a fine, fixed grain.
struct IslandCardSurface: View {
    let tint: AssistDesignTokens.IslandCard.Tint

    var body: some View {
        ZStack {
            tint.fill

            if let texture = IslandCardGrain.texture {
                Image(decorative: texture, scale: IslandCardGrain.scale)
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(CardTokens.grainOpacity)
            }
        }
        .compositingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A repeatable noise tile, generated once, so the grain looks the same on
/// every card and in every launch.
@MainActor
enum IslandCardGrain {
    static let scale: CGFloat = 2
    static let texture: CGImage? = makeTexture(pixels: 96)

    /// Lays the grain over `rect` in the current AppKit drawing context.
    static func draw(in rect: NSRect) {
        guard let texture, let context = NSGraphicsContext.current?.cgContext else { return }
        let tileSize = CGSize(width: CGFloat(texture.width) / scale, height: CGFloat(texture.height) / scale)
        context.saveGState()
        context.clip(to: rect)
        context.setBlendMode(.overlay)
        context.setAlpha(CardTokens.grainOpacity)
        context.draw(texture, in: CGRect(origin: rect.origin, size: tileSize), byTiling: true)
        context.restoreGState()
    }

    private static func makeTexture(pixels size: Int) -> CGImage? {
        // xorshift64* with a fixed seed.
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        var bytes = [UInt8](repeating: 0, count: size * size)
        for index in bytes.indices {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            bytes[index] = UInt8(truncatingIfNeeded: (state &* 0x2545_F491_4F6C_DD1D) >> 56)
        }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
