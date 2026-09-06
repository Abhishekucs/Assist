import AppKit
import Darwin
import ImageIO
import SQLite3
import UniformTypeIdentifiers

final class CaptureStore {
    static let interruptedTranscriptionError =
        "Transcription was interrupted because Assist closed before local transcription completed."

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let supportDirectory: URL
    private let legacySupportDirectory: URL?
    private let replacementDataWriter: @Sendable (Data, URL) throws -> Void
    private let replacementDirectorySwapper: @Sendable (URL, URL) throws -> Void

    private var capturesDirectory: URL {
        supportDirectory.appendingPathComponent("Captures", isDirectory: true)
    }

    private var databaseURL: URL {
        supportDirectory.appendingPathComponent("captures.sqlite")
    }

    private var legacyMetadataURL: URL {
        supportDirectory.appendingPathComponent("captures.json")
    }

    init(
        applicationSupportDirectory: URL? = nil,
        replacementDataWriter: (@Sendable (Data, URL) throws -> Void)? = nil,
        replacementDirectorySwapper: (@Sendable (URL, URL) throws -> Void)? = nil
    ) {
        if let applicationSupportDirectory {
            supportDirectory = applicationSupportDirectory
            legacySupportDirectory = nil
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            supportDirectory = base.appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
            legacySupportDirectory = AppIdentity.legacySupportDirectoryName.map {
                base.appendingPathComponent($0, isDirectory: true)
            }
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.replacementDataWriter = replacementDataWriter ?? { data, url in
            try data.write(to: url, options: .atomic)
        }
        self.replacementDirectorySwapper =
            replacementDirectorySwapper ?? CaptureImageReplacementTarget.atomicSwap

        migrateLegacySupportDirectoryIfNeeded()
        try? fileManager.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
        cleanupInterruptedImageReplacementDirectories()
        try? initializeDatabase()
        rewriteLegacyCapturePathsIfNeeded()
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
            defer {
                if statement != nil {
                    sqlite3_finalize(statement)
                }
            }

            var items: [CaptureItem] = []
            var staleItems: [CaptureItem] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let item = decodeItem(from: statement) else { continue }
                if fileManager.fileExists(atPath: item.imagePath) {
                    items.append(item)
                } else {
                    staleItems.append(item)
                }
            }

            sqlite3_finalize(statement)
            statement = nil

            if !staleItems.isEmpty {
                try deleteCaptureRows(staleItems.map(\.id), in: database)
                staleItems.forEach { try? removeCaptureFiles(for: $0) }
                let staleCount = staleItems.count
                Task { @MainActor in
                    DebugLogger.log("store.stale-captures.pruned", [
                        "count": "\(staleCount)"
                    ])
                }
            }

            return items
        }) ?? []
    }

    func loadTextItems() -> [TextClipItem] {
        (try? withDatabase { database in
            let sql = """
            SELECT id, created_at, text
            FROM text_clips
            ORDER BY created_at DESC
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
            defer { sqlite3_finalize(statement) }

            var items: [TextClipItem] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let item = decodeTextItem(from: statement) else { continue }
                items.append(item)
            }

            return items
        }) ?? []
    }

    func save(image: NSImage, context: ScreenshotContext) throws -> CaptureItem {
        let id = UUID()
        let captureDirectoryURL = capturesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        let imageURL = captureDirectoryURL.appendingPathComponent("screenshot.png", isDirectory: false)
        let thumbURL = captureDirectoryURL.appendingPathComponent("thumbnail.png", isDirectory: false)

        let item = CaptureItem(
            id: id,
            createdAt: Date(),
            imagePath: imageURL.path,
            thumbnailPath: thumbURL.path,
            context: context
        )

        var didCreateCaptureDirectory = false
        do {
            try fileManager.createDirectory(
                at: captureDirectoryURL,
                withIntermediateDirectories: false
            )
            didCreateCaptureDirectory = true
            try writePNG(image, to: imageURL)
            try writePNG(image.thumbnail(maxDimension: 480), to: thumbURL)
            try writeContext(for: item)
            try upsert(item: item)
            return item
        } catch {
            if didCreateCaptureDirectory {
                try? fileManager.removeItem(at: captureDirectoryURL)
            }
            throw error
        }
    }

    func replaceImage(for item: CaptureItem, with image: NSImage) throws {
        let target = try imageReplacementTarget(for: item)
        guard let replacementImageData = image.pngData,
              let replacementThumbnailData = image.thumbnail(maxDimension: 480).pngData else {
            throw AppError.imageEncodingFailed
        }
        try target.replace(
            imageData: replacementImageData,
            thumbnailData: replacementThumbnailData
        )
    }

    func imageReplacementTarget(for item: CaptureItem) throws -> CaptureImageReplacementTarget {
        guard let captureDirectoryURL = item.captureDirectoryURL else {
            throw StoreError.imageReplacement(
                path: item.imagePath,
                message: "The screenshot is not stored in a managed capture directory."
            )
        }

        let imageURL = captureDirectoryURL.appendingPathComponent("screenshot.png", isDirectory: false)
        let thumbnailURL = captureDirectoryURL.appendingPathComponent("thumbnail.png", isDirectory: false)

        return CaptureImageReplacementTarget(
            captureDirectoryURL: captureDirectoryURL,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            dataWriter: replacementDataWriter,
            directorySwapper: replacementDirectorySwapper
        )
    }

    func update(item: CaptureItem) throws {
        guard let contextFileURL = item.contextFileURL else {
            try upsert(item: item)
            return
        }

        let previousContextData: Data?
        if fileManager.fileExists(atPath: contextFileURL.path) {
            do {
                previousContextData = try Data(contentsOf: contextFileURL)
            } catch {
                throw StoreError.contextRead(
                    path: contextFileURL.path,
                    message: error.localizedDescription
                )
            }
        } else {
            previousContextData = nil
        }

        try writeContext(for: item)
        do {
            try upsert(item: item)
        } catch {
            let updateError = error
            do {
                if let previousContextData {
                    try previousContextData.write(to: contextFileURL, options: .atomic)
                } else if fileManager.fileExists(atPath: contextFileURL.path) {
                    try fileManager.removeItem(at: contextFileURL)
                }
            } catch {
                throw StoreError.contextRollback(
                    path: contextFileURL.path,
                    updateMessage: updateError.localizedDescription,
                    rollbackMessage: error.localizedDescription
                )
            }
            throw updateError
        }
    }

    @discardableResult
    func recoverInterruptedTranscriptions() throws -> Int {
        let interruptedItems = loadItems().filter {
            $0.context.dictation?.status == .transcribing
        }

        for var item in interruptedItems {
            item.context.dictation?.status = .failed
            item.context.dictation?.errorDetails = Self.interruptedTranscriptionError
            try update(item: item)
        }

        return interruptedItems.count
    }

    func delete(item: CaptureItem) throws {
        try withDatabase { database in
            let sql = "DELETE FROM captures WHERE id = ?"

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
            defer { sqlite3_finalize(statement) }

            bindText(item.id.uuidString, to: statement, at: 1)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
        }

        do {
            try removeCaptureFiles(for: item)
        } catch {
            // Keep the index and files consistent when filesystem deletion fails.
            // The database row is restored before the original error is surfaced.
            try? upsert(item: item)
            throw error
        }
    }

    func save(text: String) throws -> TextClipItem {
        let item = TextClipItem(
            id: UUID(),
            createdAt: Date(),
            text: text
        )

        try upsert(textItem: item)
        return item
    }

    func delete(textItem: TextClipItem) throws {
        try withDatabase { database in
            let sql = "DELETE FROM text_clips WHERE id = ?"

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
            defer { sqlite3_finalize(statement) }

            bindText(textItem.id.uuidString, to: statement, at: 1)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
        }
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

            CREATE TABLE IF NOT EXISTS text_clips (
                id TEXT PRIMARY KEY NOT NULL,
                created_at REAL NOT NULL,
                text TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_text_clips_created_at
            ON text_clips(created_at DESC);
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

    private func upsert(textItem: TextClipItem) throws {
        try withDatabase { database in
            let sql = """
            INSERT INTO text_clips (id, created_at, text)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                created_at = excluded.created_at,
                text = excluded.text
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
            defer { sqlite3_finalize(statement) }

            bindText(textItem.id.uuidString, to: statement, at: 1)
            sqlite3_bind_double(statement, 2, textItem.createdAt.timeIntervalSince1970)
            bindText(textItem.text, to: statement, at: 3)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
        }
    }

    private func deleteCaptureRows(_ ids: [UUID], in database: OpaquePointer?) throws {
        guard !ids.isEmpty else { return }

        let sql = "DELETE FROM captures WHERE id = ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqlite(message: lastErrorMessage(database))
        }
        defer { sqlite3_finalize(statement) }

        for id in ids {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bindText(id.uuidString, to: statement, at: 1)

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

    private func cleanupInterruptedImageReplacementDirectories() {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: capturesDirectory,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return
        }

        var removedCount = 0
        for entry in entries where Self.isImageReplacementStagingDirectory(entry) {
            do {
                try fileManager.removeItem(at: entry)
                removedCount += 1
            } catch {
                let path = entry.path
                let description = error.localizedDescription
                Task { @MainActor in
                    DebugLogger.log("store.image-replacement-cleanup.error", [
                        "path": path,
                        "description": description
                    ])
                }
            }
        }

        if removedCount > 0 {
            let completedCount = removedCount
            Task { @MainActor [completedCount] in
                DebugLogger.log("store.image-replacement-cleanup.completed", [
                    "count": "\(completedCount)"
                ])
            }
        }
    }

    private static func isImageReplacementStagingDirectory(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard name.hasPrefix("."),
              let marker = name.range(of: ".edit-") else {
            return false
        }

        let captureID = String(name[name.index(after: name.startIndex)..<marker.lowerBound])
        let transactionID = String(name[marker.upperBound...])
        return UUID(uuidString: captureID) != nil && UUID(uuidString: transactionID) != nil
    }

    private func migrateLegacySupportDirectoryIfNeeded() {
        guard let legacySupportDirectory,
              fileManager.fileExists(atPath: legacySupportDirectory.path),
              !fileManager.fileExists(atPath: supportDirectory.path) else {
            return
        }

        try? fileManager.moveItem(at: legacySupportDirectory, to: supportDirectory)
    }

    private func rewriteLegacyCapturePathsIfNeeded() {
        guard let legacySupportDirectory else { return }

        let oldPrefix = legacySupportDirectory.path + "/"
        let newPrefix = supportDirectory.path + "/"

        try? withDatabase { database in
            let sql = """
            UPDATE captures
            SET
                image_path = REPLACE(image_path, ?, ?),
                thumbnail_path = REPLACE(thumbnail_path, ?, ?)
            WHERE image_path LIKE ? OR thumbnail_path LIKE ?
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
            defer { sqlite3_finalize(statement) }

            bindText(oldPrefix, to: statement, at: 1)
            bindText(newPrefix, to: statement, at: 2)
            bindText(oldPrefix, to: statement, at: 3)
            bindText(newPrefix, to: statement, at: 4)
            bindText(oldPrefix + "%", to: statement, at: 5)
            bindText(oldPrefix + "%", to: statement, at: 6)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqlite(message: lastErrorMessage(database))
            }
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

    private func decodeTextItem(from statement: OpaquePointer?) -> TextClipItem? {
        guard let idText = sqliteText(statement, column: 0),
              let id = UUID(uuidString: idText),
              let text = sqliteText(statement, column: 2) else {
            return nil
        }

        return TextClipItem(
            id: id,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
            text: text
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

    private func writeContext(for item: CaptureItem) throws {
        guard let contextFileURL = item.contextFileURL else { return }

        do {
            try Data(CaptureContextMarkdown.render(item: item).utf8)
                .write(to: contextFileURL, options: .atomic)
        } catch {
            throw StoreError.contextWrite(
                path: contextFileURL.path,
                message: error.localizedDescription
            )
        }
    }

    private func removeCaptureFiles(for item: CaptureItem) throws {
        if let captureDirectoryURL = item.captureDirectoryURL {
            if fileManager.fileExists(atPath: captureDirectoryURL.path) {
                try fileManager.removeItem(at: captureDirectoryURL)
            }
            return
        }

        for path in Set([item.imagePath, item.thumbnailPath])
        where fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }
}

struct CaptureImageReplacementTarget: Sendable {
    private let captureDirectoryURL: URL
    private let imageURL: URL
    private let thumbnailURL: URL
    private let dataWriter: @Sendable (Data, URL) throws -> Void
    private let directorySwapper: @Sendable (URL, URL) throws -> Void

    init(
        captureDirectoryURL: URL,
        imageURL: URL,
        thumbnailURL: URL,
        dataWriter: @escaping @Sendable (Data, URL) throws -> Void,
        directorySwapper: @escaping @Sendable (URL, URL) throws -> Void
    ) {
        self.captureDirectoryURL = captureDirectoryURL
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.dataWriter = dataWriter
        self.directorySwapper = directorySwapper
    }

    func replace(with image: CGImage) throws {
        guard let imageData = Self.pngData(for: image),
              let thumbnail = Self.downscaled(image, maxDimension: 480),
              let thumbnailData = Self.pngData(for: thumbnail) else {
            throw AppError.imageEncodingFailed
        }

        try replace(imageData: imageData, thumbnailData: thumbnailData)
    }

    func replace(imageData: Data, thumbnailData: Data) throws {
        let fileManager = FileManager.default
        let parentDirectoryURL = captureDirectoryURL.deletingLastPathComponent()
        let transactionID = UUID().uuidString
        let stagingURL = parentDirectoryURL.appendingPathComponent(
            ".\(captureDirectoryURL.lastPathComponent).edit-\(transactionID)",
            isDirectory: true
        )

        defer {
            if fileManager.fileExists(atPath: stagingURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            }
        }

        do {
            // Build a complete replacement next to the original. The final directory
            // replacement is one filesystem operation, so image and thumbnail cannot split.
            try fileManager.copyItem(at: captureDirectoryURL, to: stagingURL)
            try dataWriter(
                imageData,
                stagingURL.appendingPathComponent(imageURL.lastPathComponent)
            )
            try dataWriter(
                thumbnailData,
                stagingURL.appendingPathComponent(thumbnailURL.lastPathComponent)
            )
        } catch {
            throw StoreError.imageReplacement(
                path: captureDirectoryURL.path,
                message: "Unable to stage edited screenshot files: \(error.localizedDescription)"
            )
        }

        do {
            try directorySwapper(stagingURL, captureDirectoryURL)
        } catch {
            throw StoreError.imageReplacement(
                path: captureDirectoryURL.path,
                message: "Unable to atomically replace the capture directory: \(error.localizedDescription)"
            )
        }

        // The atomic swap leaves the complete original at the staging path. Removal
        // can be retried during startup if the process exits before this cleanup.
        try? fileManager.removeItem(at: stagingURL)
    }

    /// `RENAME_SWAP` from rename(2). macOS guarantees one atomic exchange when
    /// the underlying volume supports it; otherwise the syscall fails untouched.
    private static let renameSwapFlag: UInt32 = 0x00000002

    static func atomicSwap(from stagingURL: URL, to captureDirectoryURL: URL) throws {
        let swapOutcome = stagingURL.path.withCString { stagingPath in
            captureDirectoryURL.path.withCString { capturePath in
                let result = renamex_np(stagingPath, capturePath, renameSwapFlag)
                let errorCode = result == 0 ? 0 : Darwin.__error().pointee
                return (result, errorCode)
            }
        }
        guard swapOutcome.0 == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(swapOutcome.1))
        }
    }

    private static func pngData(for image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func downscaled(_ image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 0, height > 0 else { return nil }

        let scale = min(maxDimension / width, maxDimension / height, 1)
        guard scale < 1 else { return image }

        let targetWidth = max(1, Int((width * scale).rounded()))
        let targetHeight = max(1, Int((height * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
    }
}

private enum StoreError: LocalizedError {
    case encodingFailed
    case imageReplacement(path: String, message: String)
    case contextRead(path: String, message: String)
    case contextWrite(path: String, message: String)
    case contextRollback(path: String, updateMessage: String, rollbackMessage: String)
    case sqlite(message: String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Unable to encode screenshot details."
        case let .imageReplacement(path, message):
            "Unable to save the edited screenshot at \(path): \(message)"
        case let .contextRead(path, message):
            "Unable to read the existing context file at \(path) before updating it: \(message)"
        case let .contextWrite(path, message):
            "Unable to write context file at \(path): \(message)"
        case let .contextRollback(path, updateMessage, rollbackMessage):
            "Context update failed (\(updateMessage)), and Assist could not restore \(path): \(rollbackMessage)"
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
