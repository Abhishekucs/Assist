import AppKit
import SQLite3
import XCTest
@testable import Assist

final class CaptureStoreTests: XCTestCase {
    func testNewCaptureCreatesSelfContainedFolder() throws {
        let supportDirectory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }
        let store = CaptureStore(applicationSupportDirectory: supportDirectory)

        let item = try store.save(image: makeImage(), context: .saved)
        let captureDirectory = try XCTUnwrap(item.captureDirectoryURL)
        let contextFileURL = try XCTUnwrap(item.contextFileURL)

        XCTAssertEqual(captureDirectory.lastPathComponent, item.id.uuidString)
        XCTAssertEqual(URL(fileURLWithPath: item.imagePath).lastPathComponent, "screenshot.png")
        XCTAssertEqual(URL(fileURLWithPath: item.thumbnailPath).lastPathComponent, "thumbnail.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.imagePath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.thumbnailPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: contextFileURL.path))
        XCTAssertEqual(try read(contextFileURL), CaptureContextMarkdown.render(item: item))
        let loadedItem = try XCTUnwrap(store.loadItems().first)
        XCTAssertEqual(loadedItem.id, item.id)
        XCTAssertEqual(loadedItem.imagePath, item.imagePath)
        XCTAssertEqual(loadedItem.thumbnailPath, item.thumbnailPath)
        XCTAssertEqual(loadedItem.context, item.context)
        XCTAssertEqual(
            loadedItem.createdAt.timeIntervalSince1970,
            item.createdAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: supportDirectory
                    .appendingPathComponent("Captures")
                    .appendingPathComponent("\(item.id.uuidString).png")
                    .path
            )
        )
    }

    func testContextFileIsAtomicallyRewrittenForEveryTerminalState() throws {
        let supportDirectory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }
        let store = CaptureStore(applicationSupportDirectory: supportDirectory)
        var context = ScreenshotContext.saved
        context.dictation = dictation(status: .transcribing)
        var item = try store.save(image: makeImage(), context: context)
        let contextFileURL = try XCTUnwrap(item.contextFileURL)

        XCTAssertTrue(try read(contextFileURL).contains("Transcription is still in progress."))

        item.context.dictation = dictation(status: .ready, transcript: "Fix the selected compiler error.")
        try store.update(item: item)
        XCTAssertEqual(try read(contextFileURL), CaptureContextMarkdown.render(item: item))
        XCTAssertTrue(try read(contextFileURL).contains("Fix the selected compiler error."))

        item.context.dictation = dictation(status: .noSpeech)
        try store.update(item: item)
        XCTAssertTrue(try read(contextFileURL).contains("No speech was detected for this capture."))

        let exactFailure = "Whisper model could not load revision abc123."
        item.context.dictation = dictation(status: .failed, errorDetails: exactFailure)
        try store.update(item: item)
        let failedMarkdown = try read(contextFileURL)
        XCTAssertEqual(failedMarkdown, CaptureContextMarkdown.render(item: item))
        XCTAssertTrue(failedMarkdown.contains(exactFailure))
    }

    func testConsecutiveCaptureUpdatesCannotMismatchContextFiles() throws {
        let supportDirectory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }
        let store = CaptureStore(applicationSupportDirectory: supportDirectory)
        var pending = ScreenshotContext.saved
        pending.dictation = dictation(status: .transcribing)
        var first = try store.save(image: makeImage(), context: pending)
        var second = try store.save(image: makeImage(), context: pending)

        second.context.dictation = dictation(status: .ready, transcript: "Second capture instruction.")
        try store.update(item: second)
        first.context.dictation = dictation(status: .ready, transcript: "First capture instruction.")
        try store.update(item: first)

        let firstMarkdown = try read(XCTUnwrap(first.contextFileURL))
        let secondMarkdown = try read(XCTUnwrap(second.contextFileURL))
        XCTAssertTrue(firstMarkdown.contains("First capture instruction."))
        XCTAssertFalse(firstMarkdown.contains("Second capture instruction."))
        XCTAssertTrue(secondMarkdown.contains("Second capture instruction."))
        XCTAssertFalse(secondMarkdown.contains("First capture instruction."))
    }

    func testDeletingNewCaptureRemovesCompleteFolder() throws {
        let supportDirectory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }
        let store = CaptureStore(applicationSupportDirectory: supportDirectory)
        let item = try store.save(image: makeImage(), context: .saved)
        let captureDirectory = try XCTUnwrap(item.captureDirectoryURL)

        try store.delete(item: item)

        XCTAssertFalse(FileManager.default.fileExists(atPath: captureDirectory.path))
        XCTAssertTrue(store.loadItems().isEmpty)
    }

    func testDatabaseDeleteFailurePreservesCaptureFolder() throws {
        let supportDirectory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }
        let store = CaptureStore(applicationSupportDirectory: supportDirectory)
        let item = try store.save(image: makeImage(), context: .saved)
        let captureDirectory = try XCTUnwrap(item.captureDirectoryURL)
        let databaseURL = supportDirectory.appendingPathComponent("captures.sqlite")
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        XCTAssertEqual(
            sqlite3_exec(
                database,
                """
                CREATE TRIGGER prevent_capture_delete
                BEFORE DELETE ON captures
                BEGIN
                    SELECT RAISE(ABORT, 'forced delete failure');
                END;
                """,
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        XCTAssertThrowsError(try store.delete(item: item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: captureDirectory.path))
        XCTAssertEqual(store.loadItems().map(\.id), [item.id])
    }

    func testLegacyFlatFilesAreNotReorganized() throws {
        let supportDirectory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }
        let capturesDirectory = supportDirectory.appendingPathComponent("Captures", isDirectory: true)
        try FileManager.default.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
        let id = UUID()
        let imageURL = capturesDirectory.appendingPathComponent("\(id.uuidString).png")
        let thumbnailURL = capturesDirectory.appendingPathComponent("\(id.uuidString)-thumb.png")
        try Data("legacy-image".utf8).write(to: imageURL)
        try Data("legacy-thumbnail".utf8).write(to: thumbnailURL)

        _ = CaptureStore(applicationSupportDirectory: supportDirectory)
        let legacyItem = CaptureItem(
            id: id,
            createdAt: Date(),
            imagePath: imageURL.path,
            thumbnailPath: thumbnailURL.path,
            context: .saved
        )

        XCTAssertNil(legacyItem.captureDirectoryURL)
        XCTAssertNil(legacyItem.contextFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: capturesDirectory.appendingPathComponent(id.uuidString).path
            )
        )
    }

    @MainActor
    func testLegacyFlatCaptureStillCopiesGeneratedContext() throws {
        let directory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let imageURL = directory.appendingPathComponent("legacy.png")
        let image = try makeImage()
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: imageURL)
        var context = ScreenshotContext.saved
        context.dictation = dictation(status: .ready, transcript: "Explain the legacy capture.")
        let item = CaptureItem(
            id: UUID(),
            createdAt: Date(),
            imagePath: imageURL.path,
            thumbnailPath: imageURL.path,
            context: context
        )
        let pasteboard = NSPasteboard(name: .init("AssistTests.\(UUID().uuidString)"))

        try ContextPasteboardWriter(pasteboard: pasteboard).write(item)

        let pasteboardItems = try XCTUnwrap(pasteboard.pasteboardItems)
        XCTAssertEqual(pasteboardItems[0].string(forType: .string), CaptureContextMarkdown.render(item: item))
        XCTAssertEqual(pasteboardItems[1].data(forType: .png), pngData)
    }

    func testContextWriteFailureIsSurfaced() throws {
        let supportDirectory = makeTemporarySupportDirectory()
        defer { try? FileManager.default.removeItem(at: supportDirectory) }
        let store = CaptureStore(applicationSupportDirectory: supportDirectory)
        var item = try store.save(image: makeImage(), context: .saved)
        let captureDirectory = try XCTUnwrap(item.captureDirectoryURL)
        try FileManager.default.removeItem(at: captureDirectory)
        item.context.dictation = dictation(status: .ready, transcript: "Do not hide this failure.")

        XCTAssertThrowsError(try store.update(item: item)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unable to write context file"))
            XCTAssertTrue(error.localizedDescription.contains("context.md"))
        }
    }

    private func makeTemporarySupportDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistCaptureStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeImage() throws -> NSImage {
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 4,
                pixelsHigh: 4,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        bitmap.setColor(
            NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1),
            atX: 0,
            y: 0
        )
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.addRepresentation(bitmap)
        return image
    }

    private func read(_ url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    private func dictation(
        status: DictationStatus,
        transcript: String = "",
        errorDetails: String? = nil
    ) -> DictationContext {
        DictationContext(
            status: status,
            transcript: transcript,
            language: "en",
            modelIdentifier: VoiceContextService.modelIdentifier,
            modelRevision: VoiceContextService.modelRevision,
            errorDetails: errorDetails
        )
    }
}
