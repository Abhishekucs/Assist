import AppKit

/// Files dropped on the notch. The shelf remembers where files are and never
/// copies, moves, or deletes them.
@MainActor
final class ShelfStore: ObservableObject {
    static let capacity = 60

    @Published private(set) var items: [ShelfItem] = []

    private let fileURL: URL
    private var canPersist = true
    private var iconCache: [String: NSImage] = [:]

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("shelf.json", isDirectory: false)
        switch ModuleStorage.load([ShelfItem].self, from: fileURL) {
        case .missing:
            items = []
        case let .loaded(saved):
            items = saved.compactMap(Self.resolved)
        case .unreadable:
            canPersist = false
        }
    }

    /// Adds files to the front of the shelf. A file already on the shelf moves
    /// to the front instead of appearing twice.
    func add(_ urls: [URL]) {
        let fileURLs = urls.filter(\.isFileURL).map(\.standardizedFileURL)
        guard !fileURLs.isEmpty else { return }

        let newPaths = Set(fileURLs.map(\.path))
        let now = Date()
        let newItems = fileURLs.map { url in
            ShelfItem(id: UUID(), addedAt: now, path: url.path, bookmark: try? url.bookmarkData())
        }
        items = Array((newItems + items.filter { !newPaths.contains($0.path) }).prefix(Self.capacity))
        persist()
        DebugLogger.log("modules.shelf.add", ["count": "\(newItems.count)"])
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func removeAll() {
        guard !items.isEmpty else { return }
        items = []
        persist()
    }

    /// Follows renamed or moved files and drops ones that were deleted.
    func refresh() {
        let next = items.compactMap(Self.resolved)
        guard next != items else { return }
        items = next
        persist()
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func icon(for item: ShelfItem) -> NSImage {
        if let cached = iconCache[item.path] {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: item.path)
        iconCache[item.path] = icon
        return icon
    }

    private func persist() {
        guard canPersist else { return }
        ModuleStorage.save(items, to: fileURL)
    }

    private static func resolved(_ item: ShelfItem) -> ShelfItem? {
        var item = item
        if let bookmark = item.bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                item.path = url.standardizedFileURL.path
                if isStale {
                    item.bookmark = try? url.bookmarkData()
                }
            }
        }

        guard !ShelfItem.isInTrash(path: item.path),
              FileManager.default.fileExists(atPath: item.path) else { return nil }
        return item
    }
}
