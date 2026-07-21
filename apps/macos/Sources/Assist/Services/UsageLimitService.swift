import Foundation

enum UsageLimitService {
    static func loadSnapshots(claudeCodeConfigDirectory: String = "") async -> [UsageLimitSnapshot] {
        await Task.detached(priority: .utility) {
            [
                ClaudeCodeUsageAdapter(
                    claudeHome: CodingAgentConfiguration.claudeHome(
                        configuredDirectory: claudeCodeConfigDirectory
                    )
                ).loadSnapshot(),
                CodexUsageAdapter().loadSnapshot()
            ]
        }.value
    }
}

private struct ClaudeCodeUsageAdapter: Sendable {
    let claudeHome: URL

    func loadSnapshot() -> UsageLimitSnapshot {
        return LocalRateLimitReader.loadSnapshot(
            provider: .claudeCode,
            source: .claudeStatusLine,
            roots: [
                claudeHome.appendingPathComponent("projects", isDirectory: true),
                claudeHome.appendingPathComponent("sessions", isDirectory: true),
                claudeHome.appendingPathComponent("tasks", isDirectory: true)
            ],
            maxFiles: 80
        )
    }
}

private struct CodexUsageAdapter: Sendable {
    func loadSnapshot() -> UsageLimitSnapshot {
        let codexHome = Self.codexHome()

        return LocalRateLimitReader.loadSnapshot(
            provider: .codex,
            source: .codexSessionLog,
            roots: [
                codexHome.appendingPathComponent("sessions", isDirectory: true),
                codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
            ],
            maxFiles: 120
        )
    }

    private static func codexHome() -> URL {
        if let path = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }
}

private enum LocalRateLimitReader {
    private static let acceptedExtensions = Set(["jsonl", "json"])
    private static let maxTailBytes = 512 * 1_024

    static func loadSnapshot(
        provider: UsageLimitProvider,
        source: UsageLimitSource,
        roots: [URL],
        maxFiles: Int
    ) -> UsageLimitSnapshot {
        let refreshedAt = Date()
        var fiveHour: UsageLimitWindow?
        var sevenDay: UsageLimitWindow?

        for file in candidateFiles(roots: roots, maxFiles: maxFiles) {
            for value in jsonValues(in: file.url) {
                for rateLimitObject in RateLimitParser.rateLimitObjects(in: value) {
                    let parsed = RateLimitParser.windows(from: rateLimitObject)

                    if fiveHour?.isAvailable != true,
                       let window = parsed.fiveHour,
                       isCurrent(window) {
                        fiveHour = window
                    }

                    if sevenDay?.isAvailable != true,
                       let window = parsed.sevenDay,
                       isCurrent(window) {
                        sevenDay = window
                    }

                    if fiveHour?.isAvailable == true,
                       sevenDay?.isAvailable == true {
                        return UsageLimitSnapshot(
                            provider: provider,
                            fiveHour: fiveHour ?? .unavailable,
                            sevenDay: sevenDay ?? .unavailable,
                            source: source,
                            refreshedAt: refreshedAt
                        )
                    }
                }
            }
        }

        guard fiveHour?.isAvailable == true || sevenDay?.isAvailable == true else {
            return .unavailable(provider: provider, refreshedAt: refreshedAt)
        }

        return UsageLimitSnapshot(
            provider: provider,
            fiveHour: fiveHour ?? .unavailable,
            sevenDay: sevenDay ?? .unavailable,
            source: source,
            refreshedAt: refreshedAt
        )
    }

    private static func isCurrent(_ window: UsageLimitWindow) -> Bool {
        guard window.isAvailable else {
            return false
        }

        guard let resetAt = window.resetAt else {
            return true
        }

        return resetAt > Date()
    }

    private static func candidateFiles(roots: [URL], maxFiles: Int) -> [UsageLimitFile] {
        let fileManager = FileManager.default
        var files: [UsageLimitFile] = []
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard acceptedExtensions.contains(url.pathExtension.lowercased()) else {
                    continue
                }

                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else {
                    continue
                }

                files.append(
                    UsageLimitFile(
                        url: url,
                        modifiedAt: values.contentModificationDate ?? .distantPast
                    )
                )
            }
        }

        return Array(
            files
                .sorted { lhs, rhs in
                    if lhs.modifiedAt == rhs.modifiedAt {
                        return lhs.url.path > rhs.url.path
                    }

                    return lhs.modifiedAt > rhs.modifiedAt
                }
                .prefix(maxFiles)
        )
    }

    private static func jsonValues(in url: URL) -> [Any] {
        switch url.pathExtension.lowercased() {
        case "jsonl":
            return jsonLineValues(in: url)
        case "json":
            guard let data = try? Data(contentsOf: url),
                  let value = try? JSONSerialization.jsonObject(with: data) else {
                return []
            }

            return [value]
        default:
            return []
        }
    }

    private static func jsonLineValues(in url: URL) -> [Any] {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return []
        }

        defer {
            try? handle.close()
        }

        guard let fileSize = try? handle.seekToEnd() else {
            return []
        }

        let readSize = UInt64(min(Int(fileSize), maxTailBytes))
        do {
            try handle.seek(toOffset: fileSize - readSize)
            guard let data = try handle.readToEnd(),
                  !data.isEmpty else {
                return []
            }

            return String(decoding: data, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: true)
                .reversed()
                .compactMap { line in
                    guard let lineData = String(line).data(using: .utf8) else {
                        return nil
                    }

                    return try? JSONSerialization.jsonObject(with: lineData)
                }
        } catch {
            return []
        }
    }
}

private struct UsageLimitFile {
    let url: URL
    let modifiedAt: Date
}

private struct ParsedUsageLimitWindows {
    var fiveHour: UsageLimitWindow?
    var sevenDay: UsageLimitWindow?
}

private enum RateLimitParser {
    static func rateLimitObjects(in value: Any) -> [[String: Any]] {
        var results: [[String: Any]] = []
        collectRateLimitObjects(in: value, into: &results)
        return results
    }

    static func windows(from object: [String: Any]) -> ParsedUsageLimitWindows {
        let directFiveHour = windowValue(in: object, keys: [
            "five_hour",
            "fiveHour",
            "five_hour_window",
            "fiveHourWindow",
            "5h"
        ])
        let directSevenDay = windowValue(in: object, keys: [
            "seven_day",
            "sevenDay",
            "seven_day_window",
            "sevenDayWindow",
            "weekly",
            "week",
            "7d"
        ])

        if directFiveHour?.isAvailable == true || directSevenDay?.isAvailable == true {
            return ParsedUsageLimitWindows(
                fiveHour: directFiveHour,
                sevenDay: directSevenDay
            )
        }

        return ParsedUsageLimitWindows(
            fiveHour: windowValue(in: object, keys: [
                "primary",
                "primary_window",
                "primaryWindow",
                "session",
                "session_window",
                "sessionWindow"
            ]),
            sevenDay: windowValue(in: object, keys: [
                "secondary",
                "secondary_window",
                "secondaryWindow",
                "weekly",
                "weekly_window",
                "weeklyWindow"
            ])
        )
    }

    private static func collectRateLimitObjects(in value: Any, into results: inout [[String: Any]]) {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                let normalizedKey = normalized(key)
                if (normalizedKey == "ratelimits" || normalizedKey == "ratelimit"),
                   let object = child as? [String: Any] {
                    results.append(object)
                }

                collectRateLimitObjects(in: child, into: &results)
            }
            return
        }

        if let array = value as? [Any] {
            for child in array {
                collectRateLimitObjects(in: child, into: &results)
            }
        }
    }

    private static func windowValue(in object: [String: Any], keys: [String]) -> UsageLimitWindow? {
        for key in keys {
            guard let value = object.value(forNormalizedKey: key),
                  let window = parseWindow(from: value),
                  window.isAvailable else {
                continue
            }

            return window
        }

        return nil
    }

    private static func parseWindow(from value: Any) -> UsageLimitWindow? {
        if let object = value as? [String: Any] {
            let usedPercentage = percentageValue(in: object, keys: [
                "used_percentage",
                "usedPercentage",
                "usage_percentage",
                "usagePercentage",
                "percent_used",
                "percentUsed",
                "used_percent",
                "usedPercent",
                "used_pct",
                "usedPct"
            ]) ?? remainingPercentageValue(in: object, keys: [
                "remaining_percentage",
                "remainingPercentage",
                "percent_remaining",
                "percentRemaining",
                "remaining_percent",
                "remainingPercent",
                "remaining_pct",
                "remainingPct"
            ])

            let resetAt = dateValue(in: object, keys: [
                "resets_at",
                "resetsAt",
                "reset_at",
                "resetAt",
                "reset_time",
                "resetTime",
                "reset"
            ])

            return UsageLimitWindow(
                usedPercentage: usedPercentage.map { min(max($0, 0), 100) },
                resetAt: resetAt
            )
        }

        guard let usedPercentage = normalizedPercentage(from: value) else {
            return nil
        }

        return UsageLimitWindow(
            usedPercentage: min(max(usedPercentage, 0), 100),
            resetAt: nil
        )
    }

    private static func percentageValue(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object.value(forNormalizedKey: key),
               let percentage = normalizedPercentage(from: value) {
                return percentage
            }
        }

        return nil
    }

    private static func remainingPercentageValue(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object.value(forNormalizedKey: key),
               let remainingPercentage = normalizedPercentage(from: value) {
                return 100 - remainingPercentage
            }
        }

        return nil
    }

    private static func dateValue(in object: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            guard let value = object.value(forNormalizedKey: key),
                  let date = date(from: value) else {
                continue
            }

            return date
        }

        return nil
    }

    private static func normalizedPercentage(from value: Any) -> Double? {
        if let number = number(from: value) {
            if number <= 1 {
                return number * 100
            }

            guard number <= 100 else {
                return nil
            }

            return number
        }

        guard let string = value as? String else {
            return nil
        }

        let trimmed = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")

        guard let number = Double(trimmed) else {
            return nil
        }

        if number <= 1 {
            return number * 100
        }

        guard number <= 100 else {
            return nil
        }

        return number
    }

    private static func date(from value: Any) -> Date? {
        if let number = number(from: value) {
            let seconds = number > 10_000_000_000 ? number / 1_000 : number
            return Date(timeIntervalSince1970: seconds)
        }

        guard let string = value as? String else {
            return nil
        }

        if let number = Double(string) {
            let seconds = number > 10_000_000_000 ? number / 1_000 : number
            return Date(timeIntervalSince1970: seconds)
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func number(from value: Any) -> Double? {
        if value is Bool {
            return nil
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        return nil
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

private extension Dictionary where Key == String, Value == Any {
    func value(forNormalizedKey target: String) -> Any? {
        let normalizedTarget = target
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        return first { key, _ in
            key
                .lowercased()
                .filter { $0.isLetter || $0.isNumber } == normalizedTarget
        }?.value
    }
}
