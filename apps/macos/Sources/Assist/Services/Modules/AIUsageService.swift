import Foundation

/// Reads Claude Code and Codex usage from their own session logs on this Mac.
/// Nothing is installed into either tool, and nothing is sent anywhere. Logs
/// are read on a background task, only while the AI Usage module is visible.
@MainActor
final class AIUsageService: ObservableObject {
    static let refreshInterval: TimeInterval = 30

    @Published private(set) var claude: ClaudeUsageSummary?
    @Published private(set) var codex: CodexUsageSummary?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isHistoryReady = false

    private let homeDirectory: URL
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?
    private var viewerCount = 0
    private var cache = AIUsageScanner.Cache()

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    /// Starts refreshing for a view that shows usage. Balanced by `stop()`.
    func start() {
        viewerCount += 1
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        timer.tolerance = 3
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        viewerCount = max(viewerCount - 1, 0)
        guard viewerCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard refreshTask == nil else { return }
        isRefreshing = true
        let home = homeDirectory
        let previousCache = cache

        refreshTask = Task {
            let now = Date()
            var currentCache = previousCache
            if !isHistoryReady {
                let recentStart = min(Calendar.current.startOfDay(for: now), now.addingTimeInterval(-2 * UsageBlock.duration))
                let quickCache = currentCache
                let recent = await Task.detached(priority: .utility) {
                    var cache = quickCache
                    let claude = cache.claude(home: home, now: now, calendar: .current, from: recentStart)
                    let codex = cache.codex(home: home, now: now, calendar: .current, from: recentStart)
                    return (claude, codex, cache)
                }.value
                self.claude = recent.0
                self.codex = recent.1
                self.lastUpdated = now
                currentCache = recent.2
            }

            let fullCache = currentCache
            let result = await Task.detached(priority: .utility) {
                var cache = fullCache
                let claude = cache.claude(home: home, now: now, calendar: .current)
                let codex = cache.codex(home: home, now: now, calendar: .current)
                return (claude, codex, cache)
            }.value

            self.claude = result.0
            self.codex = result.1
            self.cache = result.2
            self.lastUpdated = now
            self.isHistoryReady = true
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }
}

enum AIUsageScanner {
    static let historyWeekCount = 52

    static func scanStart(now: Date, calendar: Calendar) -> Date {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let week = mondayCalendar.dateInterval(of: .weekOfYear, for: now)?.start ?? mondayCalendar.startOfDay(for: now)
        return mondayCalendar.date(byAdding: .weekOfYear, value: 1 - historyWeekCount, to: week) ?? week
    }

    // MARK: Claude Code

    /// Claude Code keeps transcripts in `~/.claude/projects`, or in
    /// `~/.config/claude/projects` for newer installs. Nil when neither exists.
    static func claudeProjectDirectories(home: URL) -> [URL] {
        [
            home.appendingPathComponent(".config/claude/projects", isDirectory: true),
            home.appendingPathComponent(".claude/projects", isDirectory: true)
        ].filter(isDirectory)
    }

    static func claude(home: URL, now: Date, calendar: Calendar) -> ClaudeUsageSummary? {
        var cache = Cache()
        return cache.claude(home: home, now: now, calendar: calendar)
    }

    // MARK: Codex

    /// Codex keeps session logs in `~/.codex/sessions/<year>/<month>/<day>/`.
    static func codexSessionsDirectory(home: URL) -> URL? {
        let directory = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        return isDirectory(directory) ? directory : nil
    }

    static func codex(home: URL, now: Date, calendar: Calendar) -> CodexUsageSummary? {
        var cache = Cache()
        return cache.codex(home: home, now: now, calendar: calendar)
    }

    struct Cache: Sendable {
        private struct ParsedFile<Value: Sendable>: Sendable {
            let modified: Date
            let size: Int
            let values: [Value]

            func matches(_ values: URLResourceValues) -> Bool {
                modified == values.contentModificationDate && size == values.fileSize
            }
        }

        private struct CodexFile: Sendable {
            let modified: Date
            let size: Int
            let scannedFrom: Date
            let scannedThrough: Date
            let usage: CodexUsageSummary.FileUsage

            func matches(_ values: URLResourceValues, from start: Date, through now: Date) -> Bool {
                modified == values.contentModificationDate && size == values.fileSize &&
                    scannedFrom <= start && scannedThrough <= now &&
                    (usage.nextFuture.map { now < $0 } ?? true)
            }
        }

        private var claudeFiles: [URL: ParsedFile<ClaudeUsageEntry>] = [:]
        private var codexFiles: [URL: CodexFile] = [:]

        mutating func claude(home: URL, now: Date, calendar: Calendar, from scanDate: Date? = nil) -> ClaudeUsageSummary? {
            let directories = AIUsageScanner.claudeProjectDirectories(home: home)
            guard !directories.isEmpty else {
                claudeFiles = [:]
                return nil
            }

            let start = scanDate ?? AIUsageScanner.scanStart(now: now, calendar: calendar)
            let files = directories.flatMap { AIUsageScanner.recentLogFiles(under: $0, modifiedSince: start) }
            let decoder = JSONDecoder()
            let timestamps = TimestampParser()
            var next: [URL: ParsedFile<ClaudeUsageEntry>] = [:]
            var entries: [ClaudeUsageEntry] = []

            for file in files {
                guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modified = values.contentModificationDate,
                      let size = values.fileSize else { continue }
                let parsed: ParsedFile<ClaudeUsageEntry>
                if let cached = claudeFiles[file], cached.matches(values) {
                    parsed = cached
                } else {
                    var entries: [ClaudeUsageEntry] = []
                    AIUsageScanner.forEachLine(of: file, containingAnyOf: [ClaudeUsageLog.lineMarker]) {
                        if let entry = ClaudeUsageLog.entry(fromLine: $0, decoder: decoder, timestamps: timestamps) {
                            entries.append(entry)
                        }
                    }
                    parsed = ParsedFile(modified: modified, size: size, values: entries)
                }
                next[file] = parsed
                entries.append(contentsOf: parsed.values.filter { $0.timestamp >= start })
            }
            claudeFiles = next
            return ClaudeUsageSummary.make(entries: entries, now: now, calendar: calendar)
        }

        mutating func codex(home: URL, now: Date, calendar: Calendar, from scanDate: Date? = nil) -> CodexUsageSummary? {
            guard let directory = AIUsageScanner.codexSessionsDirectory(home: home) else {
                codexFiles = [:]
                return nil
            }

            let start = scanDate ?? AIUsageScanner.scanStart(now: now, calendar: calendar)
            let files = AIUsageScanner.recentLogFiles(under: directory, modifiedSince: start)
            let decoder = CodexUsageLog.makeDecoder()
            let timestamps = TimestampParser()
            var next: [URL: CodexFile] = [:]
            var usages: [CodexUsageSummary.FileUsage] = []

            for file in files {
                guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let modified = values.contentModificationDate,
                      let size = values.fileSize else { continue }
                let parsed: CodexFile
                if let cached = codexFiles[file], cached.matches(values, from: start, through: now) {
                    parsed = cached
                } else {
                    var usage = CodexUsageSummary.FileUsage()
                    AIUsageScanner.forEachLine(of: file, containingAnyOf: CodexUsageLog.lineMarkers) {
                        if let line = CodexUsageLog.line(from: $0, decoder: decoder, timestamps: timestamps) {
                            usage.record(line, calendar: calendar, from: start, through: now)
                        }
                    }
                    parsed = CodexFile(modified: modified, size: size, scannedFrom: start, scannedThrough: now, usage: usage)
                }
                next[file] = parsed
                usages.append(parsed.usage)
            }
            codexFiles = next
            return CodexUsageSummary.make(files: usages, now: now, calendar: calendar, from: start)
        }
    }

    // MARK: Files

    /// `.jsonl` files changed since `date`. Older logs cannot hold newer entries.
    static func recentLogFiles(under root: URL, modifiedSince date: Date) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= date else { continue }
            files.append(url)
        }
        return files
    }

    /// Stream candidate lines so large transcripts never become a line array.
    static func forEachLine(of file: URL, containingAnyOf markers: [Data], _ body: (Data) -> Void) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        var buffer = Data()
        while let chunk = try? handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
            buffer.append(chunk)
            var cursor = buffer.startIndex
            while let newline = buffer[cursor...].firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[cursor..<newline]
                if !line.isEmpty, markers.contains(where: { line.range(of: $0) != nil }) {
                    body(Data(line))
                }
                cursor = buffer.index(after: newline)
            }
            buffer = Data(buffer[cursor...])
        }
        if !buffer.isEmpty, markers.contains(where: { buffer.range(of: $0) != nil }) {
            body(buffer)
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
