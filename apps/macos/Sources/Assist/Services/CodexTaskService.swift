import Foundation

struct CodexTask: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let workspaceName: String
    let updatedAt: Date
}

enum CodexTaskService {
    static func loadActiveTasks(limit: Int = 3) async -> [CodexTask] {
        let codexHome = codexHome()

        return await Task.detached(priority: .utility) {
            loadActiveTasks(codexHome: codexHome, limit: limit)
        }.value
    }

    static func loadActiveTasks(codexHome: URL, limit: Int = 3) -> [CodexTask] {
        guard limit > 0 else { return [] }

        return CodexTaskReader.loadActiveTasks(
            sessionsRoot: codexHome.appendingPathComponent("sessions", isDirectory: true),
            limit: min(limit, 3)
        )
    }

    private static func codexHome() -> URL {
        if let path = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }
}

private enum CodexTaskReader {
    private static let maxCandidateFiles = 120
    private static let metadataReadLimit = 128 * 1_024
    private static let reverseReadChunkSize = 256 * 1_024

    static func loadActiveTasks(sessionsRoot: URL, limit: Int) -> [CodexTask] {
        var tasks: [CodexTask] = []

        for file in candidateFiles(in: sessionsRoot) {
            guard let metadata = sessionMetadata(in: file.url),
                  !metadata.isSubagent,
                  let activeTurn = activeTurn(in: file.url) else {
                continue
            }

            tasks.append(
                CodexTask(
                    id: metadata.id,
                    title: activeTurn.title ?? "Working in \(metadata.workspaceName)",
                    workspaceName: metadata.workspaceName,
                    updatedAt: file.modifiedAt
                )
            )

            if tasks.count == limit {
                break
            }
        }

        return tasks
    }

    private static func candidateFiles(in sessionsRoot: URL) -> [CodexTaskFile] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sessionsRoot.path) else { return [] }

        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        var files: [CodexTaskFile] = []

        guard let enumerator = fileManager.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let url as URL in enumerator where url.pathExtension.lowercased() == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }

            files.append(
                CodexTaskFile(
                    url: url,
                    modifiedAt: values.contentModificationDate ?? .distantPast
                )
            )
        }

        return Array(
            files
                .sorted {
                    if $0.modifiedAt == $1.modifiedAt {
                        return $0.url.path > $1.url.path
                    }
                    return $0.modifiedAt > $1.modifiedAt
                }
                .prefix(maxCandidateFiles)
        )
    }

    private static func sessionMetadata(in url: URL) -> CodexSessionMetadata? {
        guard let text = textFromStart(of: url, byteLimit: metadataReadLimit) else {
            return nil
        }

        var sessionID: String?
        var cwd: String?
        var isSubagent = false

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let object = jsonObject(from: line),
                  let payload = object["payload"] as? [String: Any] else {
                continue
            }

            switch payload["type"] as? String {
            case "session_meta":
                break
            default:
                if object["type"] as? String != "session_meta" {
                    continue
                }
            }

            sessionID = payload["id"] as? String ?? sessionID
            cwd = payload["cwd"] as? String ?? cwd
            isSubagent = isSubagent
                || hasNonNullValue(payload["parent_thread_id"])
                || containsSubagentMarker(payload["source"])
        }

        guard let sessionID, !sessionID.isEmpty else { return nil }

        let workspaceName = cwd
            .map { URL(fileURLWithPath: $0).lastPathComponent }
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "Codex"

        return CodexSessionMetadata(
            id: sessionID,
            workspaceName: workspaceName,
            isSubagent: isSubagent
        )
    }

    private static func activeTurn(in url: URL) -> CodexActiveTurn? {
        var foundActiveStart = false

        let result: CodexActiveTurn? = scanLinesInReverse(in: url) { lineData in
            guard let object = jsonObject(from: lineData),
                  let payload = object["payload"] as? [String: Any],
                  let eventType = payload["type"] as? String else {
                return nil
            }

            if foundActiveStart {
                guard eventType == "user_message",
                      let message = payload["message"] as? String,
                      let title = taskTitle(from: message) else {
                    return nil
                }
                return CodexActiveTurn(title: title)
            }

            if eventType == "task_complete" {
                return CodexActiveTurn.inactive
            }
            if eventType == "task_started" {
                foundActiveStart = true
            }
            return nil
        }

        if let result {
            return result.isInactive ? nil : result
        }
        return foundActiveStart ? CodexActiveTurn(title: nil) : nil
    }

    private static func taskTitle(from message: String) -> String? {
        let candidate: String

        if let start = message.range(of: "<user_query>"),
           let end = message.range(of: "</user_query>", range: start.upperBound..<message.endIndex) {
            candidate = String(message[start.upperBound..<end.lowerBound])
        } else {
            candidate = message
        }

        let normalized = candidate
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty,
              !normalized.hasPrefix("<environment_context>"),
              !normalized.hasPrefix("<system_reminder>") else {
            return nil
        }

        return String(normalized.prefix(100))
    }

    private static func containsSubagentMarker(_ value: Any?) -> Bool {
        if let dictionary = value as? [String: Any] {
            return dictionary.contains { key, child in
                key.lowercased().contains("subagent") || containsSubagentMarker(child)
            }
        }
        if let array = value as? [Any] {
            return array.contains { containsSubagentMarker($0) }
        }
        if let string = value as? String {
            return string.lowercased().contains("subagent")
        }
        return false
    }

    private static func hasNonNullValue(_ value: Any?) -> Bool {
        guard let value else { return false }
        return !(value is NSNull)
    }

    private static func jsonObject(from line: Substring) -> [String: Any]? {
        guard let data = String(line).data(using: .utf8) else { return nil }
        return jsonObject(from: data)
    }

    private static func jsonObject(from data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func textFromStart(of url: URL, byteLimit: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data = try? handle.read(upToCount: byteLimit)
        guard let data, !data.isEmpty else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func scanLinesInReverse<Result>(
        in url: URL,
        inspect: (Data) -> Result?
    ) -> Result? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd() else { return nil }
        var position = size
        var leadingFragment = Data()

        while position > 0 {
            let readSize = min(UInt64(reverseReadChunkSize), position)
            let start = position - readSize

            do {
                try handle.seek(toOffset: start)
                guard var chunk = try handle.read(upToCount: Int(readSize)) else {
                    return nil
                }
                chunk.append(leadingFragment)

                let lines = chunk.split(separator: 0x0A, omittingEmptySubsequences: true)
                let linesToInspect = start > 0 ? lines.dropFirst() : lines[...]

                for line in linesToInspect.reversed() {
                    if let result = inspect(Data(line)) {
                        return result
                    }
                }

                leadingFragment = start > 0 ? Data(lines.first ?? chunk[...]) : Data()
                position = start
            } catch {
                return nil
            }
        }

        return nil
    }
}

private struct CodexTaskFile {
    let url: URL
    let modifiedAt: Date
}

private struct CodexSessionMetadata {
    let id: String
    let workspaceName: String
    let isSubagent: Bool
}

private struct CodexActiveTurn {
    let title: String?
    let isInactive: Bool

    init(title: String?) {
        self.title = title
        isInactive = false
    }

    private init(title: String?, isInactive: Bool) {
        self.title = title
        self.isInactive = isInactive
    }

    static let inactive = CodexActiveTurn(title: nil, isInactive: true)
}
