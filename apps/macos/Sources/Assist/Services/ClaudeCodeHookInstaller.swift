import Darwin
import Foundation

enum ClaudeCodeHookInstallerError: LocalizedError {
    case invalidSettingsFile
    case missingExecutable

    var errorDescription: String? {
        switch self {
        case .invalidSettingsFile:
            "The existing Claude Code settings.json file is not a JSON object. Assist left it unchanged."
        case .missingExecutable:
            "Assist could not locate its executable for the Claude Code hook."
        }
    }
}

struct ClaudeCodeHookInstaller {
    private static let commandMarker = "--claude-code-hook"
    private static let ownerMarkerPrefix = "--assist-hook-owner="
    private static let managedEvents = [
        "SessionStart",
        "UserPromptSubmit",
        "PreToolUse",
        "PostToolUse",
        "PostToolUseFailure",
        "PermissionRequest",
        "Notification",
        "Stop",
        "StopFailure",
        "SessionEnd"
    ]

    private let fileManager: FileManager
    private let claudeHome: URL
    private let ownerIdentifier: String

    init(
        fileManager: FileManager = .default,
        claudeHome: URL? = nil,
        ownerIdentifier: String = AppIdentity.bundleIdentifier
    ) {
        self.fileManager = fileManager
        self.claudeHome = claudeHome ?? CodingAgentConfiguration.claudeHome(
            configuredDirectory: "",
            fileManager: fileManager
        )
        self.ownerIdentifier = ownerIdentifier
    }

    var settingsURL: URL {
        claudeHome.appendingPathComponent("settings.json")
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
                return handlers.contains(where: isOwnedAssistHandler)
            }
        }
    }

    func install(executableURL: URL?) throws {
        guard let executableURL else {
            throw ClaudeCodeHookInstallerError.missingExecutable
        }

        var root = try loadRoot()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        let executablePath = executableURL.standardizedFileURL.path
        var command = "\(Self.shellQuote(executablePath)) \(Self.commandMarker) \(ownerMarker)"
        if let version = installedClaudeCodeVersion() {
            command += " \(CodingAgentHookIPC.versionArgumentPrefix)\(Self.shellQuote(version))"
        }

        for event in Self.managedEvents {
            if let existing = hooks[event], !(existing is [[String: Any]]) {
                throw ClaudeCodeHookInstallerError.invalidSettingsFile
            }
            let existingGroups = hooks[event] as? [[String: Any]] ?? []
            var groups = removingAllAssistHandlers(from: existingGroups)
            var handler: [String: Any] = [
                "type": "command",
                "command": command,
                "timeout": ["PermissionRequest", "PreToolUse"].contains(event) ? 600 : 5
            ]
            if event == "PermissionRequest" {
                handler["statusMessage"] = "Waiting for approval in Assist"
            } else if event == "PreToolUse" {
                handler["statusMessage"] = "Waiting for an answer in Assist"
            }

            var group: [String: Any] = ["hooks": [handler]]
            switch event {
            case "PreToolUse", "PostToolUse", "PostToolUseFailure":
                group["matcher"] = "AskUserQuestion"
            case "PermissionRequest":
                group["matcher"] = "*"
            case "Notification":
                group["matcher"] = "elicitation_dialog|elicitation_complete|elicitation_response|agent_needs_input|agent_completed"
            default:
                break
            }
            groups.append(group)
            hooks[event] = groups
        }

        root["hooks"] = hooks
        try write(root)
    }

    func uninstall() throws {
        guard fileManager.fileExists(atPath: settingsURL.path) else { return }

        var root = try loadRoot()
        guard var hooks = root["hooks"] as? [String: Any] else { return }
        for event in Array(hooks.keys) {
            guard let groups = hooks[event] as? [[String: Any]] else { continue }
            hooks[event] = removingOwnedAssistHandlers(from: groups)
        }
        root["hooks"] = hooks
        try write(root)
    }

    private var ownerMarker: String {
        "\(Self.ownerMarkerPrefix)\(ownerIdentifier)"
    }

    private func loadRoot() throws -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCodeHookInstallerError.invalidSettingsFile
        }
        if let hooks = root["hooks"], !(hooks is [String: Any]) {
            throw ClaudeCodeHookInstallerError.invalidSettingsFile
        }
        return root
    }

    private func write(_ root: [String: Any]) throws {
        let writeURL = try resolvedSettingsWriteURL()
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

    private func resolvedSettingsWriteURL() throws -> URL {
        var metadata = stat()
        guard lstat(settingsURL.path, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFLNK else {
            return settingsURL
        }
        let destination = try fileManager.destinationOfSymbolicLink(atPath: settingsURL.path)
        let destinationURL = destination.hasPrefix("/")
            ? URL(fileURLWithPath: destination)
            : settingsURL.deletingLastPathComponent().appendingPathComponent(destination)
        return destinationURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func removingOwnedAssistHandlers(from groups: [[String: Any]]) -> [[String: Any]] {
        filteredGroups(groups) { handler in
            !isOwnedAssistHandler(handler)
        }
    }

    private func removingAllAssistHandlers(from groups: [[String: Any]]) -> [[String: Any]] {
        filteredGroups(groups) { handler in
            !isAnyOwnedAssistHandler(handler)
        }
    }

    private func filteredGroups(
        _ groups: [[String: Any]],
        keeping shouldKeep: ([String: Any]) -> Bool
    ) -> [[String: Any]] {
        groups.compactMap { group in
            guard let handlers = group["hooks"] as? [[String: Any]] else { return group }
            let remainingHandlers = handlers.filter(shouldKeep)
            guard !remainingHandlers.isEmpty else { return nil }
            var updatedGroup = group
            updatedGroup["hooks"] = remainingHandlers
            return updatedGroup
        }
    }

    private func isOwnedAssistHandler(_ handler: [String: Any]) -> Bool {
        guard let command = handler["command"] as? String,
              command.contains(Self.commandMarker) else {
            return false
        }
        return command.split(whereSeparator: \.isWhitespace).contains(Substring(ownerMarker))
    }

    private func isAnyOwnedAssistHandler(_ handler: [String: Any]) -> Bool {
        guard let command = handler["command"] as? String,
              command.contains(Self.commandMarker) else {
            return false
        }
        return command.split(whereSeparator: \.isWhitespace).contains { argument in
            argument.hasPrefix(Self.ownerMarkerPrefix)
        }
    }

    private func installedClaudeCodeVersion() -> String? {
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/claude"),
            URL(fileURLWithPath: "/opt/homebrew/bin/claude"),
            URL(fileURLWithPath: "/usr/local/bin/claude")
        ]
        guard let executableURL = candidates.first(where: {
            fileManager.isExecutableFile(atPath: $0.path)
        }) else {
            return nil
        }

        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return text.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
