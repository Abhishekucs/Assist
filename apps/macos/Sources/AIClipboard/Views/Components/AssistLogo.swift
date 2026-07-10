import AppKit
import SwiftUI

struct AssistLogo: View {
    let size: CGFloat

    init(size: CGFloat = 16) {
        self.size = size
    }

    var body: some View {
        Group {
            if let image = AssistLogoImageStore.image() {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(.white.opacity(0.18))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
enum AssistLogoImageStore {
    private static var cache: NSImage?

    static func image() -> NSImage? {
        if let cache {
            return cache
        }

        guard let url = logoURL(),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = false
        cache = image
        return image
    }

    static func menuBarImage() -> NSImage? {
        guard let image = image()?.copy() as? NSImage else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    private static func logoURL() -> URL? {
        if let url = Bundle.main.url(
            forResource: "assist-icon",
            withExtension: "svg",
            subdirectory: "Brand"
        ) {
            return url
        }

        if let url = Bundle.module.url(
            forResource: "assist-icon",
            withExtension: "svg",
            subdirectory: "Brand"
        ) {
            return url
        }

        return nil
    }
}
