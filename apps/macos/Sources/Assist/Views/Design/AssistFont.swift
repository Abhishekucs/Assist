import SwiftUI

enum AssistFont {
    static func title() -> Font {
        .system(.title3, design: .default).weight(.semibold)
    }

    static func section() -> Font {
        .caption.weight(.medium)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .body.weight(weight)
    }

    static func small(_ weight: Font.Weight = .regular) -> Font {
        .subheadline.weight(weight)
    }

    static func caption(_ weight: Font.Weight = .regular) -> Font {
        .caption.weight(weight)
    }

    static func roundedHeadline() -> Font {
        .system(.headline, design: .rounded)
    }

    static func roundedFootnote(_ weight: Font.Weight = .regular) -> Font {
        .system(.footnote, design: .rounded).weight(weight)
    }

    static func mono() -> Font {
        .system(.caption, design: .monospaced).weight(.medium)
    }
}
