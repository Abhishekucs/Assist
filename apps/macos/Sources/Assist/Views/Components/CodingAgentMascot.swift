import AppKit
import SwiftUI

struct CodingAgentMascot: View {
    let size: CGFloat
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.28, paused: reduceMotion)) { context in
            let isRaised = !reduceMotion
                && Int(context.date.timeIntervalSinceReferenceDate / 0.28).isMultiple(of: 2)

            Group {
                if let image = CodingAgentMascotImageStore.image {
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(color)
                        .aspectRatio(contentMode: .fit)
                }
            }
            .offset(y: isRaised ? -1 : 0)
        }
        .frame(width: size, height: size)
        .help("Coding agent working")
        .accessibilityLabel("Coding agent working")
    }
}

@MainActor
private enum CodingAgentMascotImageStore {
    static let image: NSImage? = {
        guard let url = assetURL(),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.isTemplate = true
        return image
    }()

    private static func assetURL() -> URL? {
        if let url = Bundle.main.url(
            forResource: "claude-code-logo",
            withExtension: "svg",
            subdirectory: "Brand"
        ) {
            return url
        }

        return Bundle.module.url(
            forResource: "claude-code-logo",
            withExtension: "svg",
            subdirectory: "Brand"
        )
    }
}
