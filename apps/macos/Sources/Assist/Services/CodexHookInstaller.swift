import Darwin
import Foundation

enum CodexHookInstallerError: LocalizedError {
    case invalidHooksFile
    case missingExecutable

    var errorDescription: String? {
        switch self {
        case .invalidHooksFile:
            "The existing Codex hooks.json file is not a JSON object. Assist left it unchanged."
        case .missingExecutable:
            "Assist could not locate its executable for the Codex hook."
        }
    }
}

struct CodexHookInstaller {
    private static let commandMarker = "--codex-hook"
    private static let ownerMarkerPrefix = "--assist-hook-owner="
    private static let managedEvents = [
        "SessionStart",
        "UserPromptSubmit",
        "PermissionRequest",
        "Stop"
    ]

    private let fileManager: FileManager
    private let codexHome: URL
    private let ownerIdentifier: String
    private let legacyExecutablePath: String?

    init(
        fileManager: FileManager = .default,
        codexHome: URL? = nil,
        ownerIdentifier: String = AppIdentity.bundleIdentifier,
        executableURL: URL? = Bundle.main.executableURL
    ) {
        self.fileManager = fileManager
        self.codexHome = codexHome ?? Self.defaultCodexHome()
        self.ownerIdentifier = ownerIdentifier
        legacyExecutablePath = executableURL?.standardizedFileURL.path
    }

    var hooksURL: URL {
        codexHome.appendingPathComponent("hooks.json")
    }

    func isInstalled() -> Bool {
        guard let root = try? loadRoot() else { return false }
        return Self.managedEvents.allSatisfy { event in
            guard let groups = (root["hooks"] as? [String: Any])?[event] as? [[String: Any]] else {
                return false
            }

            return groups.contains { group in
                guard let handlers = group["hooks"] as? [[String: Any]] else { return false }
                return handlers.contains(where: isOwnedAssistHandler)
            }
        }
    }

    func containsAssistHandlers() -> Bool {
        guard let root = try? loadRoot(),
              let hooks = root["hooks"] as? [String: Any] else {
            return false
        }

        return hooks.values.contains { value in
            guard let groups = value as? [[String: Any]] else { return false }
            return groups.contains { group in
                guard let handlers = group["hooks"] as? [[String: Any]] else { return false }
                return handlers.contains { handler in
                    isOwnedAssistHandler(handler) || isLegacyAssistHandler(handler)
                }
            }
        }
    }

    func install(executableURL: URL?) throws {
        guard let executableURL else {
            throw CodexHookInstallerError.missingExecutable
        }

        var root = try loadRoot()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let executablePath = executableURL.standardizedFileURL.path
        let command = "\(Self.shellQuote(executablePath)) \(Self.commandMarker) \(ownerMarker)"

        for event in Self.managedEvents {
            if let existing = hooks[event], !(existing is [[String: Any]]) {
                throw CodexHookInstallerError.invalidHooksFile
            }
            let existingGroups = hooks[event] as? [[String: Any]] ?? []
            var groups = removingOwnedAssistHandlers(
                from: existingGroups,
                legacyExecutablePath: executablePath
            )
            var handler: [String: Any] = [
                "type": "command",
                "command": command,
                "timeout": event == "PermissionRequest" ? 600 : 5
            ]

            if event == "PermissionRequest" {
                handler["statusMessage"] = "Waiting for approval in Assist"
            }

            var group: [String: Any] = ["hooks": [handler]]
            if event == "PermissionRequest" {
                group["matcher"] = "*"
            }
            groups.append(group)
            hooks[event] = groups
        }

        root["hooks"] = hooks
        try write(root)
    }

    func uninstall() throws {
        guard fileManager.fileExists(atPath: hooksURL.path) else { return }

        var root = try loadRoot()
        guard var hooks = root["hooks"] as? [String: Any] else { return }

        for event in Array(hooks.keys) {
            let value = hooks[event]
            guard let groups = value as? [[String: Any]] else { continue }
            hooks[event] = removingOwnedAssistHandlers(from: groups)
        }

        root["hooks"] = hooks
        try write(root)
    }

    private func loadRoot() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: hooksURL.path) else { return [:] }

        let data = try Data(contentsOf: hooksURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexHookInstallerError.invalidHooksFile
        }
        if let hooks = root["hooks"], !(hooks is [String: Any]) {
            throw CodexHookInstallerError.invalidHooksFile
        }
        return root
    }

    private func write(_ root: [String: Any]) throws {
        let writeURL = try resolvedHooksWriteURL()
        try fileManager.createDirectory(
            at: writeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: writeURL, options: .atomic)
        _ = chmod(writeURL.path, mode_t(0o600))
    }

    private func resolvedHooksWriteURL() throws -> URL {
        var metadata = stat()
        guard lstat(hooksURL.path, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFLNK else {
            return hooksURL
        }

        let destination = try fileManager.destinationOfSymbolicLink(atPath: hooksURL.path)
        let destinationURL: URL
        if destination.hasPrefix("/") {
            destinationURL = URL(fileURLWithPath: destination)
        } else {
            destinationURL = hooksURL.deletingLastPathComponent()
                .appendingPathComponent(destination)
        }
        return destinationURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    private var ownerMarker: String {
        "\(Self.ownerMarkerPrefix)\(ownerIdentifier)"
    }

    private func removingOwnedAssistHandlers(
        from groups: [[String: Any]],
        legacyExecutablePath: String? = nil
    ) -> [[String: Any]] {
        groups.compactMap { group in
            guard let handlers = group["hooks"] as? [[String: Any]] else {
                return group
            }

            let remainingHandlers = handlers.filter { handler in
                !isOwnedAssistHandler(handler)
                    && !isLegacyAssistHandler(
                        handler,
                        executablePath: legacyExecutablePath ?? self.legacyExecutablePath
                    )
            }
            guard !remainingHandlers.isEmpty else { return nil }

            var updatedGroup = group
            updatedGroup["hooks"] = remainingHandlers
            return updatedGroup
        }
    }

    private func isOwnedAssistHandler(_ handler: [String: Any]) -> Bool {
        guard let command = handler["command"] as? String else { return false }
        return command.split(whereSeparator: \.isWhitespace).contains(Substring(ownerMarker))
    }

    private func isLegacyAssistHandler(
        _ handler: [String: Any],
        executablePath: String? = nil
    ) -> Bool {
        guard let executablePath = executablePath ?? legacyExecutablePath,
              let command = handler["command"] as? String,
              command.contains(Self.commandMarker),
              !command.contains(Self.ownerMarkerPrefix) else {
            return false
        }
        return command.contains(executablePath)
    }

    private static func defaultCodexHome() -> URL {
        if let path = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(
                fileURLWithPath: (path as NSString).expandingTildeInPath,
                isDirectory: true
            )
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
