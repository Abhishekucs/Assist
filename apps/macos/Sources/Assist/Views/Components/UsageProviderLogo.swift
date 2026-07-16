import AppKit
import SwiftUI

struct UsageProviderLogo: View {
    let provider: UsageLimitProvider
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
    private static var cache: [UsageLimitProvider: NSImage] = [:]

    static func image(for provider: UsageLimitProvider) -> NSImage? {
        if let cachedImage = cache[provider] {
            return cachedImage
        }

        guard let url = logoURL(for: provider),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = false
        cache[provider] = image
        return image
    }

    private static func logoURL(for provider: UsageLimitProvider) -> URL? {
        if let url = Bundle.main.url(
            forResource: provider.logoResourceName,
            withExtension: "svg",
            subdirectory: "Brand"
        ) {
            return url
        }

        if let url = Bundle.module.url(
            forResource: provider.logoResourceName,
            withExtension: "svg",
            subdirectory: "Brand"
        ) {
            return url
        }

        return nil
    }
}

private extension UsageLimitProvider {
    var logoResourceName: String {
        switch self {
        case .claudeCode:
            "claude-code-logo"
        case .codex:
            "codex-logo"
        }
    }
}
