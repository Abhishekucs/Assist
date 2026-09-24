import AppKit
import SwiftUI

enum HugeIconKind: String {
    case settings
    case sound = "volume-high"
    case play
    case grid
    case image
    case trash
    case document
    case appearance
    case camera
    case storage
    case info
    case sun
    case moon
    case desktop
    case refresh
    case pen
    case copy
    case folder
    case check
    case circle
    case close
    case crop
    case blur
    case paintBoard = "paint-board"
    case aspectRatio = "aspect-ratio"
    case expand = "arrow-expand-diagonal-02"
    case collapse = "arrow-shrink-01"
    // Notch modules and their controls.
    case clipboard
    case shelf
    case notes
    case timer
    case calendar
    case music
    case stats
    case hourglass
    case convert
    case pause
    case next
    case previous
    case add
    case minus
    case droplet
    case cpu
    case memory
    case disk
    case network
    case battery
    case batteryCharging = "battery-charging"
    case file
    case drop
    case revenue
    case aiUsage = "ai-usage"
    case key

    var assetName: String { rawValue }
}

/// A bundled template icon. With no `color`, it takes the surrounding
/// foreground style, so `.foregroundStyle` on the icon or a parent applies.
struct HugeIcon: View {
    let kind: HugeIconKind
    let size: CGFloat
    let color: Color?

    init(_ kind: HugeIconKind, size: CGFloat = AssistDesignTokens.Icon.feedback, color: Color? = nil) {
        self.kind = kind
        self.size = size
        self.color = color
    }

    var body: some View {
        Group {
            if let image = HugeIconImageStore.image(named: kind.assetName) {
                tinted(
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.template)
                )
                .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tinted(_ image: Image) -> some View {
        if let color {
            image.foregroundStyle(color)
        } else {
            image
        }
    }
}

@MainActor
private enum HugeIconImageStore {
    private static var cache: [String: NSImage] = [:]

    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] {
            return cached
        }

        guard let url = iconURL(named: name),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = true
        cache[name] = image
        return image
    }

    private static func iconURL(named name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Icons") {
            return url
        }

        if let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Icons") {
            return url
        }

        return nil
    }
}
