import Darwin
import Foundation

/// Upgrade-only removal of configuration written by old Assist versions.
/// This service never installs hooks, reads agent logs, or handles agent requests.
struct RetiredAgentHooksCleanup {
    static let obsoletePreferenceKeys = [
        "agents.coding.enabled", "agents.codex.enabled", "agents.claude.configDirectory",
        "rateLimits.showClaudeCode", "rateLimits.showCodex"
    ]
    private static let completedPathsKey = "migrations.retiredAgentHooks.v1.completedPaths"
    private static let ownerMarkers: Set<String> = [
        "--assist-hook-owner=com.thinkingsoundlab.assist",
        "--assist-hook-owner=com.thinkingsoundlab.assist.dev"
    ]
    private static let flags: Set<String> = ["--codex-hook", "--claude-code-hook"]

    struct Result {
        var removedHandlers = 0
        var failures: [String] = []
    }

    private let defaults: UserDefaults
    private let homeDirectory: URL
    private let workingDirectory: URL
    private let supportDirectory: URL
    private let environment: [String: String]
    private let legacyExecutablePaths: Set<String>
    private let fileManager = FileManager.default

    init(
        defaults: UserDefaults = .standard,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        supportDirectory: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executableURL: URL? = Bundle.main.executableURL
    ) {
        self.defaults = defaults
        self.homeDirectory = homeDirectory
        self.workingDirectory = workingDirectory
        self.supportDirectory = supportDirectory
        self.environment = environment
        legacyExecutablePaths = Set([
            "/Applications/Assist.app/Contents/MacOS/Assist",
            "/Applications/Assist Dev.app/Contents/MacOS/Assist"
        ] + (executableURL.map { [$0.standardizedFileURL.path] } ?? []))
    }

    func run() -> Result {
        var result = Result()
        var completedPaths = Set(defaults.stringArray(forKey: Self.completedPathsKey) ?? [])

        for url in configurationURLs {
            // Keep the configured path (including a symlink) as the migration identity.
            // A new custom directory must still be retired on a later launch.
            guard !completedPaths.contains(url.path) else { continue }
            do {
                result.removedHandlers += try cleanConfiguration(at: url)
                completedPaths.insert(url.path)
            } catch {
                result.failures.append("\(url.path): \(error.localizedDescription)")
            }
        }
        defaults.set(completedPaths.sorted(), forKey: Self.completedPathsKey)

        do {
            try removeStaleSocket()
        } catch {
            result.failures.append("Socket cleanup: \(error.localizedDescription)")
        }

        // Keep the old custom-directory setting until all cleanup succeeds, so a
        // permission or JSON error never loses the location needed for the next launch.
        if result.failures.isEmpty {
            Self.obsoletePreferenceKeys.forEach { defaults.removeObject(forKey: $0) }
        }
        return result
    }

    private var configurationURLs: [URL] {
        var urls = [
            homeDirectory.appendingPathComponent(".codex/hooks.json"),
            homeDirectory.appendingPathComponent(".claude/settings.json")
        ]
        if let directory = environment["CODEX_HOME"],
           !directory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // The old Codex installer resolved relative paths against the launch
            // directory, unlike the Claude setting, which was relative to home.
            urls.append(resolveDirectory(directory, relativeTo: workingDirectory)
                .appendingPathComponent("hooks.json"))
        }
        for directory in [environment["CLAUDE_CONFIG_DIR"], defaults.string(forKey: "agents.claude.configDirectory")] {
            guard let directory,
                  !directory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            urls.append(resolveDirectory(directory.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: homeDirectory)
                .appendingPathComponent("settings.json"))
        }
        return Array(Set(urls.map(\.standardizedFileURL))).sorted { $0.path < $1.path }
    }

    private func resolveDirectory(_ path: String, relativeTo directory: URL) -> URL {
        if path == "~" { return homeDirectory }
        if path.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(path.dropFirst(2)), isDirectory: true)
        }
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") { return URL(fileURLWithPath: expanded, isDirectory: true) }
        return directory.appendingPathComponent(expanded, isDirectory: true)
    }

    private func cleanConfiguration(at url: URL) throws -> Int {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else {
            if errno == ENOENT { return 0 }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let target = url.resolvingSymlinksInPath()
        var coordinationError: NSError?
        var outcome: Swift.Result<Int, Error>?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forMerging, error: &coordinationError) { writeURL in
            outcome = Swift.Result { try rewriteConfiguration(at: writeURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw CleanupError.configurationUnavailable }
        return try outcome.get()
    }

    private func rewriteConfiguration(at url: URL) throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw CleanupError.configurationUnavailable
        }
        let original = try Data(contentsOf: url)
        guard var root = try JSONSerialization.jsonObject(with: original) as? [String: Any] else {
            throw CleanupError.invalidConfiguration
        }
        guard let rawHooks = root["hooks"] else { return 0 }
        guard var hooks = rawHooks as? [String: Any] else { throw CleanupError.invalidConfiguration }
        var removedCount = 0

        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]] else { throw CleanupError.invalidConfiguration }
            var retainedGroups: [[String: Any]] = []
            for var group in groups {
                guard let handlers = group["hooks"] as? [[String: Any]] else {
                    throw CleanupError.invalidConfiguration
                }
                let retained = handlers.filter { !isAssistHandler($0) }
                let removed = handlers.count - retained.count
                removedCount += removed
                if removed == 0 {
                    retainedGroups.append(group)
                } else if !retained.isEmpty {
                    group["hooks"] = retained
                    retainedGroups.append(group)
                }
            }
            hooks[event] = retainedGroups
        }
        guard removedCount > 0 else { return 0 }
        root["hooks"] = hooks
        let updated = try JSONSerialization.data(
            withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        let replacement = url.deletingLastPathComponent()
            .appendingPathComponent(".assist-retirement-\(UUID().uuidString).json")
        defer { try? fileManager.removeItem(at: replacement) }
        // Configuration may contain secrets. Keep the temporary copy private from
        // its creation, not just after writing its contents.
        let descriptor = Darwin.open(replacement.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        try handle.write(contentsOf: updated)
        try handle.synchronize()
        try handle.close()
        if let permissions = attributes[.posixPermissions] {
            try fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: replacement.path)
        }
        // Do not overwrite a non-coordinating editor's changes made while we parsed.
        guard try Data(contentsOf: url) == original else { throw CleanupError.configurationChanged }
        // Native replacement preserves the original file's metadata, including ACLs.
        _ = try fileManager.replaceItemAt(url, withItemAt: replacement)
        return removedCount
    }

    private func isAssistHandler(_ handler: [String: Any]) -> Bool {
        guard handler["type"] as? String == "command",
              let command = handler["command"] as? String,
              let words = Self.commandWords(command), words.count >= 2,
              URL(fileURLWithPath: words[0]).lastPathComponent == "Assist",
              Self.flags.contains(words[1]) else { return false }
        if words.contains(where: Self.ownerMarkers.contains) { return true }
        // Early versions did not include an owner marker. Match their exact
        // executable path, never a substring in an unrelated user's shell command.
        return words.count == 2 && legacyExecutablePaths.contains(words[0])
    }

    /// Parse the simple quoted command emitted by Assist; never evaluate a shell.
    /// More complex user-authored shell expressions are deliberately left alone.
    private static func commandWords(_ command: String) -> [String]? {
        var words: [String] = []
        var word = ""
        var quote: Character?
        var escaped = false
        for character in command {
            if escaped { word.append(character); escaped = false; continue }
            if character == "\\", quote != "'" { escaped = true; continue }
            if let activeQuote = quote {
                if character == activeQuote { quote = nil } else { word.append(character) }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character.isWhitespace {
                if !word.isEmpty { words.append(word); word = "" }
            } else if ";|&<>$`".contains(character) {
                return nil
            } else {
                word.append(character)
            }
        }
        guard quote == nil, !escaped else { return nil }
        if !word.isEmpty { words.append(word) }
        return words
    }

    private func removeStaleSocket() throws {
        let url = supportDirectory.appendingPathComponent("coding-agent.sock")
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else {
            if errno == ENOENT { return }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard metadata.st_mode & S_IFMT == S_IFSOCK, metadata.st_uid == getuid() else {
            throw CleanupError.unexpectedSocketFile
        }
        // Another old Assist process may still own the socket. Do not disconnect it.
        var address = sockaddr_un()
        let pathBytes = Array(url.path.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw CleanupError.unexpectedSocketFile
        }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            pathBytes.withUnsafeBytes { destination.copyBytes(from: $0) }
        }
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw CleanupError.unexpectedSocketFile }
        defer { Darwin.close(descriptor) }
        // A full backlog on an older process must not block normal app startup.
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected != 0, errno == ECONNREFUSED else { throw CleanupError.socketStillActive }
        var currentMetadata = stat()
        guard lstat(url.path, &currentMetadata) == 0,
              currentMetadata.st_dev == metadata.st_dev,
              currentMetadata.st_ino == metadata.st_ino else { throw CleanupError.socketStillActive }
        try fileManager.removeItem(at: url)
    }

    private enum CleanupError: LocalizedError {
        case invalidConfiguration, configurationUnavailable, configurationChanged
        case unexpectedSocketFile, socketStillActive

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration: "Invalid hook configuration; the file was left unchanged."
            case .configurationUnavailable: "The configuration is not an accessible regular file."
            case .configurationChanged: "The configuration changed during cleanup; retry on next launch."
            case .unexpectedSocketFile: "The old socket path was left unchanged because its identity could not be verified."
            case .socketStillActive: "Quit the older Assist instance to finish socket cleanup."
            }
        }
    }
}

/// Old provider configurations can invoke a new binary before its first normal
/// launch. Exit without starting AppKit or making any approval/answer decision.
enum RetiredAgentHookCommand {
    static func isInvocation(_ arguments: [String]) -> Bool {
        arguments.contains("--codex-hook") || arguments.contains("--claude-code-hook")
    }

    static func response(arguments: [String], payload: Data) -> Data {
        guard arguments.contains("--codex-hook"),
              let event = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              event["hook_event_name"] as? String == "Stop" else { return Data() }
        return Data("{}\n".utf8)
    }

    static func run(arguments: [String]) -> Int32 {
        var payload = Data()
        while let chunk = try? FileHandle.standardInput.read(upToCount: 8_192), !chunk.isEmpty {
            guard payload.count + chunk.count <= 1_048_576 else { return 0 }
            payload.append(chunk)
        }
        FileHandle.standardOutput.write(response(arguments: arguments, payload: payload))
        return 0
    }
}
