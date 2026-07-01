import AppKit
import SQLite3

final class CaptureStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var supportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AIClipboard", isDirectory: true)
    }

    private var capturesDirectory: URL {
        supportDirectory.appendingPathComponent("Captures", isDirectory: true)
    }

    private var databaseURL: URL {
        supportDirectory.appendingPathComponent("captures.sqlite")
    }

    private var legacyMetadataURL: URL {
        supportDirectory.appendingPathComponent("captures.json")
    }

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
        try? initializeDatabase()
        migrateLegacyJSONIfNeeded()
    }

    func loadItems() -> [CaptureItem] {
        (try? withDatabase { database in
            let sql = """
            SELECT id, created_at, image_path, thumbnail_path, context_json
            FROM captures
            ORDER BY created_at DESC
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
            defer { sqlite3_finalize(statement) }

            var items: [CaptureItem] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let item = decodeItem(from: statement) else { continue }
                items.append(item)
            }

            return items
        }) ?? []
    }

    func save(image: NSImage, context: ScreenshotContext) throws -> CaptureItem {
        let id = UUID()
        let imageURL = capturesDirectory.appendingPathComponent("\(id.uuidString).png")
        let thumbURL = capturesDirectory.appendingPathComponent("\(id.uuidString)-thumb.png")

        try writePNG(image, to: imageURL)
        try writePNG(image.thumbnail(maxDimension: 480), to: thumbURL)

        let item = CaptureItem(
            id: id,
            createdAt: Date(),
            imagePath: imageURL.path,
            thumbnailPath: thumbURL.path,
            context: context
        )

        try upsert(item: item)
        return item
    }

    func update(item: CaptureItem) {
        try? upsert(item: item)
    }

    private func initializeDatabase() throws {
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        try withDatabase { database in
            let sql = """
            CREATE TABLE IF NOT EXISTS captures (
                id TEXT PRIMARY KEY NOT NULL,
                created_at REAL NOT NULL,
                image_path TEXT NOT NULL,
                thumbnail_path TEXT NOT NULL,
                context_json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_captures_created_at
            ON captures(created_at DESC);
            """

            guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
        }
    }

    private func upsert(item: CaptureItem) throws {
        let contextData = try encoder.encode(item.context)
        guard let contextJSON = String(data: contextData, encoding: .utf8) else {
            throw StoreError.encodingFailed
        }

        try withDatabase { database in
            let sql = """
            INSERT INTO captures (id, created_at, image_path, thumbnail_path, context_json)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                created_at = excluded.created_at,
                image_path = excluded.image_path,
                thumbnail_path = excluded.thumbnail_path,
                context_json = excluded.context_json
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
            defer { sqlite3_finalize(statement) }

            bindText(item.id.uuidString, to: statement, at: 1)
            sqlite3_bind_double(statement, 2, item.createdAt.timeIntervalSince1970)
            bindText(item.imagePath, to: statement, at: 3)
            bindText(item.thumbnailPath, to: statement, at: 4)
            bindText(contextJSON, to: statement, at: 5)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
        }
    }

    private func migrateLegacyJSONIfNeeded() {
        guard fileManager.fileExists(atPath: legacyMetadataURL.path),
              loadItems().isEmpty,
              let data = try? Data(contentsOf: legacyMetadataURL),
              let items = try? decoder.decode([CaptureItem].self, from: data) else {
            return
        }

        for item in items {
            try? upsert(item: item)
        }
    }

    private func decodeItem(from statement: OpaquePointer?) -> CaptureItem? {
        guard let idText = sqliteText(statement, column: 0),
              let id = UUID(uuidString: idText),
              let imagePath = sqliteText(statement, column: 2),
              let thumbnailPath = sqliteText(statement, column: 3),
              let contextJSON = sqliteText(statement, column: 4),
              let contextData = contextJSON.data(using: .utf8),
              let context = try? decoder.decode(ScreenshotContext.self, from: contextData) else {
            return nil
        }

        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))

        return CaptureItem(
            id: id,
            createdAt: createdAt,
            imagePath: imagePath,
            thumbnailPath: thumbnailPath,
            context: context
        )
    }

    private func withDatabase<T>(_ body: (OpaquePointer?) throws -> T) throws -> T {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            let message = database.map(lastErrorMessage) ?? "Unable to open SQLite database."
            sqlite3_close(database)
            throw StoreError.sqlite(message: message)
        }

        defer { sqlite3_close(database) }
        return try body(database)
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, value, -1, transient)
    }

    private func sqliteText(_ statement: OpaquePointer?, column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else {
            return nil
        }

        return String(cString: pointer)
    }

    private func lastErrorMessage(_ database: OpaquePointer?) -> String {
        guard let error = sqlite3_errmsg(database) else {
            return "Unknown SQLite error."
        }

        return String(cString: error)
    }

    private func writePNG(_ image: NSImage, to url: URL) throws {
        guard let data = image.pngData else {
            throw AppError.imageEncodingFailed
        }

        try data.write(to: url, options: .atomic)
    }
}

private enum StoreError: LocalizedError {
    case encodingFailed
    case sqlite(message: String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Unable to encode screenshot context."
        case let .sqlite(message):
            "Database error: \(message)"
        }
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    func thumbnail(maxDimension: CGFloat) -> NSImage {
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let image = NSImage(size: newSize)

        image.lockFocus()
        draw(in: CGRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1)
        image.unlockFocus()

        return image
    }
}
