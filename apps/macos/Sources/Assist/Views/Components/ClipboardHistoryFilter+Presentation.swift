import SwiftUI

/// How a history filter is presented, shared by the library and the island.
extension ClipboardHistoryFilter {
    /// The library sidebar's label, which empty states refer to by name.
    var navigationTitle: String {
        self == .all ? "All history" : title
    }

    var icon: HugeIconKind {
        switch self {
        case .all: .grid
        case .text: .document
        case .images: .image
        }
    }

    /// The glyph above an empty state: a capture for all history, otherwise
    /// the filter's own icon.
    var emptyIcon: HugeIconKind {
        self == .all ? .camera : icon
    }

    /// The heading shown when nothing matches this filter.
    var emptyTitle: String {
        switch self {
        case .all: "No captures yet"
        case .text: "No text yet"
        case .images: "No images yet"
        }
    }
}

enum LibraryContentFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case images
    case links

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    func includes(_ item: ClipboardHistoryItem) -> Bool {
        switch (self, item) {
        case (.all, _), (.images, .screenshot):
            true
        case let (.text, .text(clip)):
            clip.linkURL == nil
        case let (.links, .text(clip)):
            clip.linkURL != nil
        default:
            false
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "No captures yet"
        case .text: "No text yet"
        case .images: "No images yet"
        case .links: "No links yet"
        }
    }
}
