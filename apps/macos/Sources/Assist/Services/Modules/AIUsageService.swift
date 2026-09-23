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

    private let homeDirectory: URL
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?
    private var viewerCount = 0

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

        refreshTask = Task {
            let now = Date()
            let result = await Task.detached(priority: .utility) {
                (
                    AIUsageScanner.claude(home: home, now: now, calendar: .current),
                    AIUsageScanner.codex(home: home, now: now, calendar: .current)
                )
            }.value

            self.claude = result.0
            self.codex = result.1
            self.lastUpdated = now
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }
}

/// Finds and parses the recent session logs of each tool. Stateless, so it
/// runs off the main thread.
enum AIUsageScanner {
    /// Enough history for today and for a five-hour window that began before midnight.
    static func scanStart(now: Date, calendar: Calendar) -> Date {
        min(calendar.startOfDay(for: now), now.addingTimeInterval(-2 * UsageBlock.duration))
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
        let directories = claudeProjectDirectories(home: home)
        guard !directories.isEmpty else { return nil }

        let start = scanStart(now: now, calendar: calendar)
        let decoder = JSONDecoder()
        let timestamps = TimestampParser()
        var entries: [ClaudeUsageEntry] = []

        for file in directories.flatMap({ recentLogFiles(under: $0, modifiedSince: start) }) {
            for line in lines(of: file, containingAnyOf: [ClaudeUsageLog.lineMarker]) {
                if let entry = ClaudeUsageLog.entry(fromLine: line, decoder: decoder, timestamps: timestamps),
                   entry.timestamp >= start {
                    entries.append(entry)
                }
            }
        }
        return ClaudeUsageSummary.make(entries: entries, now: now, calendar: calendar)
    }

    // MARK: Codex

    /// Codex keeps session logs in `~/.codex/sessions/<year>/<month>/<day>/`.
    static func codexSessionsDirectory(home: URL) -> URL? {
        let directory = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        return isDirectory(directory) ? directory : nil
    }

    static func codex(home: URL, now: Date, calendar: Calendar) -> CodexUsageSummary? {
        guard let directory = codexSessionsDirectory(home: home) else { return nil }

        let start = scanStart(now: now, calendar: calendar)
        let decoder = CodexUsageLog.makeDecoder()
        let timestamps = TimestampParser()
        let sessions = recentLogFiles(under: directory, modifiedSince: start).map { file in
            lines(of: file, containingAnyOf: CodexUsageLog.lineMarkers).compactMap { line in
                CodexUsageLog.line(from: line, decoder: decoder, timestamps: timestamps)
            }
        }
        return CodexUsageSummary.make(sessions: sessions, now: now, calendar: calendar)
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

    /// The file's lines that contain one of `markers`, so only lines that can
    /// hold usage are decoded.
    static func lines(of file: URL, containingAnyOf markers: [Data]) -> [Data] {
        guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { return [] }
        return data
            .split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
            .filter { line in markers.contains { line.range(of: $0) != nil } }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
