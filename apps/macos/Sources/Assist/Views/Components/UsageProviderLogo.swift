import AppKit
import SwiftUI

struct UsageProviderLogo: View {
    let provider: CodingAgentProvider
    let size: CGFloat

    var body: some View {
        Group {
            if let image = UsageProviderLogoImageStore.image(for: provider) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
            } else {
                Circle()
                    .fill(.white.opacity(0.24))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
private enum UsageProviderLogoImageStore {
    private static var cache: [CodingAgentProvider: NSImage] = [:]

    static func image(for provider: CodingAgentProvider) -> NSImage? {
        if let cachedImage = cache[provider] {
            return cachedImage
        }

        guard let logoResourceName = provider.logoResourceName,
              let url = logoURL(for: logoResourceName),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = false
        cache[provider] = image
        return image
    }

    private static func logoURL(for resourceName: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "svg",
            subdirectory: "Brand"
        ) {
            return url
        }

        if let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "svg",
            subdirectory: "Brand"
        ) {
            return url
        }

        return nil
    }
}
