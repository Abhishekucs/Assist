import Foundation

struct TokenCounts: Equatable, Sendable {
    var input: Int64 = 0
    var output: Int64 = 0
    var cacheCreation: Int64 = 0
    var cacheRead: Int64 = 0

    var total: Int64 {
        input + output + cacheCreation + cacheRead
    }

    mutating func add(_ other: TokenCounts) {
        input += other.input
        output += other.output
        cacheCreation += other.cacheCreation
        cacheRead += other.cacheRead
    }
}

enum TokenFormatting {
    /// "950", "84K", "1.2M".
    static func compact(_ tokens: Int64) -> String {
        tokens.formatted(.number.notation(.compactName).precision(.significantDigits(1...3)))
    }
}

// MARK: - Claude Code

/// One API response recorded in a Claude Code transcript
/// (`~/.claude/projects/<project>/<session>.jsonl`).
struct ClaudeUsageEntry: Equatable, Sendable {
    let timestamp: Date
    /// Message and request IDs; the same response can be logged more than once.
    let dedupeKey: String?
    let tokens: TokenCounts
    let model: String?
    /// Set when Claude Code logged that the usage limit was reached.
    let limitResetAt: Date?

    /// The prompt the request carried, which is its use of the context window.
    var contextTokens: Int64 {
        tokens.input + tokens.cacheCreation + tokens.cacheRead
    }
}

enum ClaudeUsageLog {
    /// A byte sequence every usage line contains, to skip other lines cheaply.
    static let lineMarker = Data("\"usage\"".utf8)

    static func entry(
        fromLine line: Data,
        decoder: JSONDecoder = JSONDecoder(),
        timestamps: TimestampParser = TimestampParser()
    ) -> ClaudeUsageEntry? {
        guard let record = try? decoder.decode(Line.self, from: line),
              let usage = record.message?.usage,
              let timestamp = record.timestamp.flatMap(timestamps.date(from:)) else { return nil }

        let dedupeKey: String? = if let messageID = record.message?.id, let requestID = record.requestId {
            "\(messageID):\(requestID)"
        } else {
            nil
        }

        return ClaudeUsageEntry(
            timestamp: timestamp,
            dedupeKey: dedupeKey,
            tokens: TokenCounts(
                input: usage.inputTokens ?? 0,
                output: usage.outputTokens ?? 0,
                cacheCreation: usage.cacheCreationInputTokens ?? 0,
                cacheRead: usage.cacheReadInputTokens ?? 0
            ),
            model: record.message?.model,
            limitResetAt: record.isApiErrorMessage == true ? limitReset(in: record.message?.texts ?? []) : nil
        )
    }

    /// Claude Code writes "Claude AI usage limit reached|<unix time>" when a
    /// limit is hit; the number is when the limit resets.
    static func limitReset(in texts: [String]) -> Date? {
        for text in texts where text.contains("usage limit reached") {
            guard let bar = text.lastIndex(of: "|") else { continue }
            let digits = text[text.index(after: bar)...].prefix(while: \.isNumber)
            if let seconds = TimeInterval(digits), seconds > 0 {
                return Date(timeIntervalSince1970: seconds)
            }
        }
        return nil
    }

    private struct Line: Decodable {
        let timestamp: String?
        let requestId: String?
        let isApiErrorMessage: Bool?
        let message: Message?
    }

    private struct Message: Decodable {
        let id: String?
        let model: String?
        let usage: Usage?
        let texts: [String]

        private enum CodingKeys: String, CodingKey {
            case id, model, usage, content
        }

        private struct Content: Decodable {
            let text: String?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try? container.decode(String.self, forKey: .id)
            model = try? container.decode(String.self, forKey: .model)
            usage = try? container.decode(Usage.self, forKey: .usage)
            // Content is a string for prompts and a list of blocks for responses.
            texts = ((try? container.decode([Content].self, forKey: .content)) ?? []).compactMap(\.text)
        }
    }

    private struct Usage: Decodable {
        let inputTokens: Int64?
        let outputTokens: Int64?
        let cacheCreationInputTokens: Int64?
        let cacheReadInputTokens: Int64?

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }
    }
}

/// Claude's usage limits reset on five-hour windows that start with the first
/// request after a quiet period. Windows here follow the same rule as ccusage:
/// a window starts on the hour of its first request and ends five hours later,
/// or earlier if five hours pass without a request.
struct UsageBlock: Equatable, Sendable {
    static let duration: TimeInterval = 5 * 60 * 60

    let start: Date
    var lastActivity: Date
    var tokens = TokenCounts()
    var requests = 0

    var end: Date {
        start.addingTimeInterval(Self.duration)
    }

    func isActive(at now: Date) -> Bool {
        now < end && now.timeIntervalSince(lastActivity) < Self.duration
    }

    func elapsedFraction(at now: Date) -> Double {
        min(max(now.timeIntervalSince(start) / Self.duration, 0), 1)
    }
}

struct ClaudeUsageSummary: Equatable, Sendable {
    static let standardContextWindow: Int64 = 200_000
    static let extendedContextWindow: Int64 = 1_000_000

    var today = TokenCounts()
    var todayRequests = 0
    var dailyTokens: [Date: Int64] = [:]
    /// The five-hour window in progress, if any.
    var activeBlock: UsageBlock?
    var contextTokens: Int64?
    var model: String?
    var lastActivity: Date?
    /// When a usage limit that Claude Code reported as reached resets.
    var limitResetAt: Date?

    /// Transcripts do not record the window size, so a prompt larger than the
    /// standard window means the 1M-token variant is in use.
    var contextWindow: Int64 {
        (contextTokens ?? 0) > Self.standardContextWindow ? Self.extendedContextWindow : Self.standardContextWindow
    }

    static func make(entries: [ClaudeUsageEntry], now: Date, calendar: Calendar) -> ClaudeUsageSummary {
        var seen = Set<String>()
        let unique = entries
            .filter { entry in
                guard let key = entry.dedupeKey else { return true }
                return seen.insert(key).inserted
            }
            .sorted { $0.timestamp < $1.timestamp }

        var summary = ClaudeUsageSummary()
        let startOfToday = calendar.startOfDay(for: now)
        var block: UsageBlock?

        for entry in unique where entry.timestamp <= now {
            let day = calendar.startOfDay(for: entry.timestamp)
            summary.dailyTokens[day, default: 0] += entry.tokens.total
            if entry.timestamp >= startOfToday {
                summary.today.add(entry.tokens)
                summary.todayRequests += 1
            }

            if var current = block,
               entry.timestamp.timeIntervalSince(current.start) <= UsageBlock.duration,
               entry.timestamp.timeIntervalSince(current.lastActivity) <= UsageBlock.duration {
                current.tokens.add(entry.tokens)
                current.requests += 1
                current.lastActivity = entry.timestamp
                block = current
            } else {
                block = UsageBlock(
                    start: floorToHour(entry.timestamp, calendar: calendar),
                    lastActivity: entry.timestamp,
                    tokens: entry.tokens,
                    requests: 1
                )
            }

            if entry.contextTokens > 0 {
                summary.contextTokens = entry.contextTokens
                summary.model = entry.model
            }
            if let reset = entry.limitResetAt, reset > now {
                summary.limitResetAt = reset
            }
            summary.lastActivity = entry.timestamp
        }

        if let block, block.isActive(at: now) {
            summary.activeBlock = block
        }
        return summary
    }

    static func floorToHour(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .hour, for: date)?.start ?? date
    }
}

// MARK: - Codex

/// A rate-limit window from Codex's `token_count` events.
struct CodexRateLimitWindow: Equatable, Sendable {
    /// From 0 to 100.
    let usedPercent: Double
    let windowMinutes: Int64?
    let resetsAt: Date?

    /// "5-hour limit", "Weekly limit", or a length in hours.
    var title: String {
        switch windowMinutes {
        case 300?: "5-hour limit"
        case 10_080?: "Weekly limit"
        case let minutes? where minutes >= 60: "\(minutes / 60)-hour limit"
        case let minutes?: "\(minutes)-minute limit"
        case nil: "Limit"
        }
    }

    /// Once the reported window resets, its old percentage is no longer current.
    func current(at now: Date) -> CodexRateLimitWindow? {
        guard resetsAt.map({ $0 <= now }) != true else { return nil }
        return self
    }
}

/// The parts of a Codex session log (`~/.codex/sessions/…/rollout-*.jsonl`)
/// that describe usage.
enum CodexLogLine: Equatable, Sendable {
    /// A `turn_context` line, which names the model for the turns after it.
    case model(String)
    case tokenCount(CodexTokenCount)
}

struct CodexTokenCount: Equatable, Sendable {
    let timestamp: Date
    /// Tokens used by the latest turn.
    let lastTotalTokens: Int64?
    /// Tokens used by the whole session so far.
    let sessionTotalTokens: Int64?
    let contextWindow: Int64?
    let primary: CodexRateLimitWindow?
    let secondary: CodexRateLimitWindow?
}

enum CodexUsageLog {
    static let lineMarkers = [Data("\"token_count\"".utf8), Data("\"turn_context\"".utf8)]

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    static func line(
        from data: Data,
        decoder: JSONDecoder = CodexUsageLog.makeDecoder(),
        timestamps: TimestampParser = TimestampParser()
    ) -> CodexLogLine? {
        guard let record = try? decoder.decode(Line.self, from: data) else { return nil }

        if record.type == "turn_context" {
            return record.payload?.model.map(CodexLogLine.model)
        }

        guard record.type == "event_msg",
              let payload = record.payload,
              payload.type == "token_count",
              let timestamp = record.timestamp.flatMap(timestamps.date(from:)) else { return nil }

        func window(_ raw: Window?) -> CodexRateLimitWindow? {
            guard let raw else { return nil }
            // Older Codex versions wrote seconds until the reset instead of a time.
            let resetsAt = raw.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
                ?? raw.resetsInSeconds.map { timestamp.addingTimeInterval(TimeInterval($0)) }
            return CodexRateLimitWindow(
                usedPercent: min(max(raw.usedPercent, 0), 100),
                windowMinutes: raw.windowMinutes,
                resetsAt: resetsAt
            )
        }

        return .tokenCount(CodexTokenCount(
            timestamp: timestamp,
            lastTotalTokens: payload.info?.lastTokenUsage?.totalTokens,
            sessionTotalTokens: payload.info?.totalTokenUsage?.totalTokens,
            contextWindow: payload.info?.modelContextWindow,
            primary: window(payload.rateLimits?.primary),
            secondary: window(payload.rateLimits?.secondary)
        ))
    }

    private struct Line: Decodable {
        let timestamp: String?
        let type: String
        let payload: Payload?
    }

    private struct Payload: Decodable {
        let type: String?
        let model: String?
        let info: Info?
        let rateLimits: RateLimits?

        private enum CodingKeys: String, CodingKey {
            case type, model, info
            case rateLimits = "rate_limits"
        }

        // Other event payloads reuse these names with other shapes, so each
        // field is read on its own and skipped when it does not match.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try? container.decode(String.self, forKey: .type)
            model = try? container.decode(String.self, forKey: .model)
            info = try? container.decode(Info.self, forKey: .info)
            rateLimits = try? container.decode(RateLimits.self, forKey: .rateLimits)
        }
    }

    private struct Info: Decodable {
        let totalTokenUsage: Usage?
        let lastTokenUsage: Usage?
        let modelContextWindow: Int64?

        private enum CodingKeys: String, CodingKey {
            case totalTokenUsage = "total_token_usage"
            case lastTokenUsage = "last_token_usage"
            case modelContextWindow = "model_context_window"
        }
    }

    private struct Usage: Decodable {
        let totalTokens: Int64?

        private enum CodingKeys: String, CodingKey {
            case totalTokens = "total_tokens"
        }
    }

    private struct RateLimits: Decodable {
        let primary: Window?
        let secondary: Window?
    }

    private struct Window: Decodable {
        let usedPercent: Double
        let windowMinutes: Int64?
        let resetsAt: Int64?
        let resetsInSeconds: Int64?

        private enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case windowMinutes = "window_minutes"
            case resetsAt = "resets_at"
            case resetsInSeconds = "resets_in_seconds"
        }
    }
}

struct CodexUsageSummary: Equatable, Sendable {
    var todayTokens: Int64 = 0
    var dailyTokens: [Date: Int64] = [:]
    var primary: CodexRateLimitWindow?
    var secondary: CodexRateLimitWindow?
    var contextTokens: Int64?
    var contextWindow: Int64?
    var model: String?
    var lastActivity: Date?

    struct FileUsage: Sendable {
        var dailyTokens: [Date: Int64] = [:]
        var latestLimits: CodexTokenCount?
        var latestContext: CodexTokenCount?
        var contextModel: String?
        var lastActivity: Date?
        var nextFuture: Date?
        private var model: String?
        private var previousSessionTotal: Int64?

        mutating func record(_ line: CodexLogLine, calendar: Calendar, from start: Date, through now: Date) {
            switch line {
            case let .model(name):
                model = name
            case let .tokenCount(count):
                let turnTokens = count.sessionTotalTokens.map { max($0 - (previousSessionTotal ?? 0), 0) }
                    ?? count.lastTotalTokens ?? 0
                if let total = count.sessionTotalTokens {
                    previousSessionTotal = total
                }
                if count.timestamp > now {
                    nextFuture = min(nextFuture ?? count.timestamp, count.timestamp)
                } else if count.timestamp >= start {
                    dailyTokens[calendar.startOfDay(for: count.timestamp), default: 0] += turnTokens
                }
                if count.primary != nil || count.secondary != nil,
                   count.timestamp >= latestLimits?.timestamp ?? .distantPast {
                    latestLimits = count
                }
                if count.contextWindow != nil, count.lastTotalTokens != nil,
                   count.timestamp >= latestContext?.timestamp ?? .distantPast {
                    latestContext = count
                    contextModel = model
                }
                if count.timestamp >= lastActivity ?? .distantPast {
                    lastActivity = count.timestamp
                }
            }
        }
    }

    /// Builds the summary from each session's lines in file order.
    static func make(sessions: [[CodexLogLine]], now: Date, calendar: Calendar) -> CodexUsageSummary {
        let files = sessions.map { lines in
            var usage = FileUsage()
            for line in lines {
                usage.record(line, calendar: calendar, from: .distantPast, through: now)
            }
            return usage
        }
        return make(files: files, now: now, calendar: calendar, from: .distantPast)
    }

    static func make(files: [FileUsage], now: Date, calendar: Calendar, from start: Date) -> CodexUsageSummary {
        var summary = CodexUsageSummary()
        var latestLimits: CodexTokenCount?
        var latestContext: CodexTokenCount?

        for file in files {
            for (day, tokens) in file.dailyTokens where day >= start {
                summary.dailyTokens[day, default: 0] += tokens
            }
            if let limits = file.latestLimits, limits.timestamp >= latestLimits?.timestamp ?? .distantPast {
                latestLimits = limits
            }
            if let context = file.latestContext, context.timestamp >= latestContext?.timestamp ?? .distantPast {
                latestContext = context
                summary.model = file.contextModel
            }
            if let activity = file.lastActivity, activity >= summary.lastActivity ?? .distantPast {
                summary.lastActivity = activity
            }
        }

        summary.todayTokens = summary.dailyTokens[calendar.startOfDay(for: now)] ?? 0
        summary.primary = latestLimits?.primary?.current(at: now)
        summary.secondary = latestLimits?.secondary?.current(at: now)
        summary.contextTokens = latestContext?.lastTotalTokens
        summary.contextWindow = latestContext?.contextWindow
        return summary
    }
}
