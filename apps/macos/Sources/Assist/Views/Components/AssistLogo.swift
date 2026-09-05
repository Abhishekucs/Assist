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
    private static var logoCache: NSImage?
    private static var menuBarCache: NSImage?

    static func image() -> NSImage? {
        if let logoCache {
            return logoCache
        }

        guard let url = logoURL(),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = false
        logoCache = image
        return image
    }

    static func menuBarImage() -> NSImage? {
        if let menuBarCache {
            return menuBarCache
        }

        guard let url = menuBarLogoURL(),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        menuBarCache = image
        return image
    }

    private static func logoURL() -> URL? {
        if let url = Bundle.main.url(
            forResource: "assist-icon",
            withExtension: "png",
            subdirectory: "Brand"
        ) {
            return url
        }

        if let url = Bundle.module.url(
            forResource: "assist-icon",
            withExtension: "png",
            subdirectory: "Brand"
        ) {
            return url
        }

        return nil
    }

    private static func menuBarLogoURL() -> URL? {
        if let url = Bundle.main.url(
            forResource: "assist-menu-bar",
            withExtension: "png",
            subdirectory: "Brand"
        ) {
            return url
        }

        if let url = Bundle.module.url(
            forResource: "assist-menu-bar",
            withExtension: "png",
            subdirectory: "Brand"
        ) {
            return url
        }

        return nil
    }
}
