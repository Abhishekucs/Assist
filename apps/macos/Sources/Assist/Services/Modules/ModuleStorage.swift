import Foundation

/// Where the notch modules keep their local files: a `Modules` folder in
/// Assist's Application Support directory. Nothing here leaves the Mac.
@MainActor
enum ModuleStorage {
    static var defaultDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
            .appendingPathComponent("Modules", isDirectory: true)
    }

    /// Decodes a module's saved JSON. A missing file is a first launch; an
    /// unreadable one is logged and left on disk rather than overwritten.
    static func load<Value: Decodable>(_ type: Value.Type, from url: URL) -> LoadResult<Value> {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }

        do {
            let data = try Data(contentsOf: url)
            return .loaded(try JSONDecoder().decode(type, from: data))
        } catch {
            DebugLogger.log("modules.storage.load.error", [
                "file": url.lastPathComponent,
                "description": error.localizedDescription
            ])
            return .unreadable
        }
    }

    static func save<Value: Encodable>(_ value: Value, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            DebugLogger.log("modules.storage.save.error", [
                "file": url.lastPathComponent,
                "description": error.localizedDescription
            ])
        }
    }

    enum LoadResult<Value> {
        case missing
        case loaded(Value)
        /// The file exists but could not be decoded. Callers keep it read-only
        /// for the session so a newer or damaged file is never replaced.
        case unreadable
    }
}
