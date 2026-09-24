import Foundation

/// A file kept on the notch shelf. The shelf holds references, never copies:
/// the bookmark follows the file when it is renamed or moved.
struct ShelfItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let addedAt: Date
    var path: String
    var bookmark: Data?

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var displayName: String {
        url.lastPathComponent
    }

    /// Files moved to the Trash leave the shelf, as if they were deleted.
    static func isInTrash(path: String) -> Bool {
        path.contains("/.Trash/") || path.contains("/.Trashes/")
    }
}
