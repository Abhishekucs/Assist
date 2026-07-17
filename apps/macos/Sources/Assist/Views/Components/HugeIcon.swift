import AppKit
import SwiftUI

enum HugeIconKind: String {
    case settings
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
    case arrowUpRight = "arrow-up-right"

    var assetName: String { rawValue }
}

struct HugeIcon: View {
    let kind: HugeIconKind
    let size: CGFloat
    let color: Color?
    @Environment(\.assistTheme) private var theme

    init(_ kind: HugeIconKind, size: CGFloat = 18, color: Color? = nil) {
        self.kind = kind
        self.size = size
        self.color = color
    }

    var body: some View {
        Group {
            if let image = HugeIconImageStore.image(named: kind.assetName) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(color ?? theme.foreground)
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
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
