import Combine
import XCTest
@testable import Assist

final class RevenueParsingTests: XCTestCase {
    func testStripeKeepsSucceededChargesLessRefunds() throws {
        let json = """
        {"object":"list","url":"/v1/charges","has_more":false,"data":[
          {"id":"ch_1","amount":2000,"amount_refunded":500,"currency":"usd","created":1790157600,"paid":true,"status":"succeeded"},
          {"id":"ch_2","amount":1000,"amount_refunded":0,"currency":"usd","created":1790157600,"paid":false,"status":"failed"},
          {"id":"ch_3","amount":3000,"amount_refunded":3000,"currency":"eur","created":1790157600,"paid":true,"status":"succeeded"}
        ]}
        """
        let page = try RevenueParsing.decoder().decode(RevenueParsing.StripeChargesPage.self, from: Data(json.utf8))
        let transactions = RevenueParsing.transactions(from: page)

        XCTAssertFalse(page.hasMore)
        XCTAssertEqual(transactions.map(\.id), ["ch_1"])
        XCTAssertEqual(transactions.first?.amountMinor, 1500)
        XCTAssertEqual(transactions.first?.currency, "USD")
        XCTAssertEqual(transactions.first?.createdAt, Date(timeIntervalSince1970: 1_790_157_600))
    }

    func testPolarCountsPaidOrdersNetOfRefundsBeforeTax() throws {
        let json = """
        {"items":[
          {"id":"o1","created_at":"2026-09-22T10:00:00.123456Z","paid":true,"status":"paid","net_amount":1000,"total_amount":1200,"refunded_amount":0,"refunded_tax_amount":0,"currency":"usd"},
          {"id":"o2","created_at":"2026-09-21T10:00:00Z","paid":true,"status":"partially_refunded","net_amount":1000,"refunded_amount":600,"refunded_tax_amount":100,"currency":"usd"},
          {"id":"o3","created_at":"2026-09-20T10:00:00Z","paid":false,"status":"pending","net_amount":900,"refunded_amount":0,"currency":"usd"}
        ],"pagination":{"total_count":3,"max_page":1}}
        """
        let page = try RevenueParsing.decoder().decode(RevenueParsing.PolarOrdersPage.self, from: Data(json.utf8))
        let transactions = RevenueParsing.transactions(from: page)

        XCTAssertEqual(page.pagination.maxPage, 1)
        XCTAssertEqual(transactions.map(\.id), ["o1", "o2"])
        XCTAssertEqual(transactions.map(\.amountMinor), [1000, 500])
        XCTAssertNotNil(transactions.first?.createdAt)
    }

    func testDodoCountsSucceededPaymentsThatWereNotFullyRefunded() throws {
        let json = """
        {"items":[
          {"payment_id":"pay_1","brand_id":"b","created_at":"2026-09-22T10:00:00Z","currency":"INR","total_amount":49900,"status":"succeeded","payment_provider":"dodo"},
          {"payment_id":"pay_2","created_at":"2026-09-22T11:00:00Z","currency":"USD","total_amount":900,"status":"succeeded","refund_status":"full"},
          {"payment_id":"pay_3","created_at":"2026-09-22T12:00:00Z","currency":"USD","total_amount":900,"status":"failed"},
          {"payment_id":"pay_4","created_at":"2026-09-22T13:00:00Z","currency":"USD","total_amount":900,"status":"succeeded","refund_status":"partial"}
        ]}
        """
        let page = try RevenueParsing.decoder().decode(RevenueParsing.DodoPaymentsPage.self, from: Data(json.utf8))
        XCTAssertEqual(RevenueParsing.transactions(from: page).map(\.id), ["pay_1", "pay_4"])
    }

    func testSummaryAddsWindowsPerCurrency() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12)))
        func sale(_ id: String, _ amount: Int64, _ currency: String, daysAgo: Int, provider: RevenueProvider = .stripe) -> RevenueTransaction {
            RevenueTransaction(
                provider: provider,
                id: id,
                amountMinor: amount,
                currency: currency,
                createdAt: now.addingTimeInterval(-TimeInterval(daysAgo) * 24 * 60 * 60)
            )
        }

        let summary = RevenueSummary.make(from: [
            sale("a", 1_000, "USD", daysAgo: 0),
            sale("a2", 250, "USD", daysAgo: 0, provider: .polar),
            sale("b", 2_000, "USD", daysAgo: 3, provider: .polar),
            sale("c", 500, "EUR", daysAgo: 6),
            sale("d", 4_000, "USD", daysAgo: 20, provider: .dodo),
            sale("e", 9_000, "USD", daysAgo: 45)
        ], now: now, calendar: calendar)

        XCTAssertEqual(summary.totals[.today]?.amounts, ["USD": 1_250])
        XCTAssertEqual(summary.totals[.week]?.amounts, ["USD": 3_250, "EUR": 500])
        XCTAssertEqual(summary.totals[.week]?.currencies, ["USD", "EUR"])
        XCTAssertEqual(summary.totals[.month]?.amounts, ["USD": 7_250, "EUR": 500])
        XCTAssertEqual(summary.totals[.month]?.count, 5)
        XCTAssertEqual(summary.providerTotals[.dodo]?.amounts, ["USD": 4_000])
        XCTAssertEqual(summary.providerTotals[.polar]?.amounts, ["USD": 2_250])
        let today = calendar.startOfDay(for: now)
        let usd = summary.dailyAmounts(for: "USD", now: now, calendar: calendar)
        XCTAssertEqual(usd.count, 30)
        XCTAssertEqual(usd.first?.day, calendar.date(byAdding: .day, value: -29, to: today))
        XCTAssertEqual(usd.last, RevenueDailyAmount(day: today, amountMinor: 1_250))
        XCTAssertEqual(usd[26].amountMinor, 2_000)
        XCTAssertEqual(usd[9].amountMinor, 4_000)
        XCTAssertEqual(usd[23].amountMinor, 0, "Days without USD sales remain zero, not EUR revenue")
        XCTAssertEqual(summary.dailyAmounts(for: "EUR", now: now, calendar: calendar)[23].amountMinor, 500)
    }

    func testDailyRevenueUsesLocalDaysAcrossDSTAndWindowBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 12)))
        let start = RevenueWindow.month.start(now: now, calendar: calendar)
        let dstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        func sale(_ id: String, at date: Date) -> RevenueTransaction {
            RevenueTransaction(provider: .stripe, id: id, amountMinor: 100, currency: "USD", createdAt: date)
        }
        let summary = RevenueSummary.make(from: [
            sale("before", at: start.addingTimeInterval(-1)),
            sale("first", at: start),
            sale("dst", at: dstDay),
            sale("today", at: now),
            sale("future", at: now.addingTimeInterval(1))
        ], now: now, calendar: calendar)
        let points = summary.dailyAmounts(for: "USD", now: now, calendar: calendar)

        XCTAssertEqual(points.count, 30)
        XCTAssertEqual(points.first, RevenueDailyAmount(day: start, amountMinor: 100))
        XCTAssertEqual(points[28], RevenueDailyAmount(day: calendar.startOfDay(for: dstDay), amountMinor: 100))
        XCTAssertEqual(points.last, RevenueDailyAmount(day: calendar.startOfDay(for: now), amountMinor: 100))
        XCTAssertEqual(summary.totals[.month]?.count, 3)
        XCTAssertEqual(RevenueSummary.make(from: [], now: now, calendar: calendar)
            .dailyAmounts(for: "USD", now: now, calendar: calendar).map(\.amountMinor), Array(repeating: 0, count: 30))
    }

    func testDailyRevenuePreservesNegativeNetDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let summary = RevenueSummary.make(from: [
            RevenueTransaction(provider: .stripe, id: "sale", amountMinor: 500, currency: "USD", createdAt: now),
            RevenueTransaction(provider: .stripe, id: "refund", amountMinor: -800, currency: "USD", createdAt: yesterday)
        ], now: now, calendar: calendar)
        let points = summary.dailyAmounts(for: "USD", now: now, calendar: calendar)

        XCTAssertEqual(points[28].amountMinor, -800)
        XCTAssertEqual(points[29].amountMinor, 500)
        XCTAssertEqual(summary.totals[.month]?.amounts["USD"], -300)
    }

    func testMoneyUsesEachCurrencysMinorUnit() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(MoneyFormatting.minorUnitDigits(for: "USD"), 2)
        XCTAssertEqual(MoneyFormatting.minorUnitDigits(for: "JPY"), 0)
        XCTAssertEqual(MoneyFormatting.format(minor: 123_456, currency: "USD", locale: locale), "$1,234.56")
        XCTAssertEqual(MoneyFormatting.format(minor: 500, currency: "JPY", locale: locale), "¥500")
    }

    func testTimestampsWithAndWithoutFractions() throws {
        let parser = TimestampParser()
        let whole = try XCTUnwrap(parser.date(from: "2026-09-22T10:00:00Z"))
        XCTAssertEqual(try XCTUnwrap(parser.date(from: "2026-09-22T10:00:00.123456Z")).timeIntervalSince(whole), 0.123, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(parser.date(from: "2026-09-22T15:30:00.5+05:30")).timeIntervalSince(whole), 0.5, accuracy: 0.001)
        XCTAssertNil(parser.date(from: "yesterday"))
    }
}

final class AIUsageParsingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func claudeLine(
        id: String,
        request: String,
        at timestamp: String,
        input: Int = 10,
        output: Int = 50,
        cacheCreation: Int = 100,
        cacheRead: Int = 1_000
    ) -> Data {
        Data("""
        {"parentUuid":null,"isSidechain":false,"cwd":"/project","sessionId":"s1","type":"assistant","message":{"id":"\(id)","type":"message","role":"assistant","model":"claude-sonnet-4-5","content":[{"type":"text","text":"Done"},{"type":"tool_use","id":"t","name":"Read","input":{}}],"usage":{"input_tokens":\(input),"cache_creation_input_tokens":\(cacheCreation),"cache_read_input_tokens":\(cacheRead),"output_tokens":\(output)}},"requestId":"\(request)","timestamp":"\(timestamp)"}
        """.utf8)
    }

    func testClaudeLinesWithUsageAreParsed() throws {
        let entry = try XCTUnwrap(ClaudeUsageLog.entry(fromLine: claudeLine(id: "m1", request: "r1", at: "2026-09-23T09:10:00.000Z")))
        XCTAssertEqual(entry.tokens.total, 1_160)
        XCTAssertEqual(entry.contextTokens, 1_110)
        XCTAssertEqual(entry.dedupeKey, "m1:r1")
        XCTAssertEqual(entry.model, "claude-sonnet-4-5")
        XCTAssertNil(entry.limitResetAt)

        let prompt = Data(#"{"type":"user","message":{"role":"user","content":"hello"},"timestamp":"2026-09-23T09:09:00.000Z"}"#.utf8)
        XCTAssertNil(ClaudeUsageLog.entry(fromLine: prompt))

        let limit = Data(#"{"type":"assistant","isApiErrorMessage":true,"message":{"id":"m9","model":"<synthetic>","content":[{"type":"text","text":"Claude AI usage limit reached|1790164800"}],"usage":{"input_tokens":0,"output_tokens":0}},"requestId":"r9","timestamp":"2026-09-23T10:00:00.000Z"}"#.utf8)
        XCTAssertEqual(ClaudeUsageLog.entry(fromLine: limit)?.limitResetAt, Date(timeIntervalSince1970: 1_790_164_800))
    }

    func testClaudeWindowsFollowFiveHourBlocks() throws {
        let lines = [
            claudeLine(id: "m0", request: "r0", at: "2026-09-22T23:00:00.000Z"),
            claudeLine(id: "m1", request: "r1", at: "2026-09-23T09:10:00.000Z"),
            claudeLine(id: "m1", request: "r1", at: "2026-09-23T09:10:00.000Z"),
            claudeLine(id: "m2", request: "r2", at: "2026-09-23T10:30:00.000Z", cacheRead: 250_000)
        ]
        let entries = lines.compactMap { ClaudeUsageLog.entry(fromLine: $0) }
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 11)))
        let summary = ClaudeUsageSummary.make(entries: entries, now: now, calendar: calendar)

        XCTAssertEqual(summary.todayRequests, 2, "Duplicate responses and yesterday's are left out")
        let yesterday = calendar.startOfDay(for: try XCTUnwrap(TimestampParser().date(from: "2026-09-22T23:00:00Z")))
        let today = calendar.startOfDay(for: now)
        XCTAssertEqual(summary.dailyTokens[yesterday], 1_160)
        XCTAssertEqual(summary.dailyTokens[today], 251_320)
        let block = try XCTUnwrap(summary.activeBlock)
        XCTAssertEqual(block.start, calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 9)))
        XCTAssertEqual(block.end, calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 14)))
        XCTAssertEqual(block.requests, 2)
        XCTAssertEqual(block.elapsedFraction(at: now), 0.4, accuracy: 0.0001)
        XCTAssertEqual(summary.contextTokens, 250_110)
        XCTAssertEqual(summary.contextWindow, ClaudeUsageSummary.extendedContextWindow)

        let later = now.addingTimeInterval(4 * 60 * 60)
        XCTAssertNil(ClaudeUsageSummary.make(entries: entries, now: later, calendar: calendar).activeBlock)
    }

    func testCodexRateLimitsAndTokensAreRead() throws {
        let lines = [
            #"{"timestamp":"2026-09-23T09:00:00.000Z","type":"turn_context","payload":{"cwd":"/p","approval_policy":"on-request","model":"gpt-5-codex","effort":"medium"}}"#,
            #"{"timestamp":"2026-09-23T09:01:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":200,"output_tokens":100,"reasoning_output_tokens":50,"total_tokens":1100},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":200,"output_tokens":100,"reasoning_output_tokens":50,"total_tokens":1100},"model_context_window":272000},"rate_limits":{"primary":{"used_percent":12.5,"window_minutes":300,"resets_at":1790164800},"secondary":{"used_percent":40,"window_minutes":10080,"resets_in_seconds":3600}}}}"#,
            #"{"timestamp":"2026-09-23T09:05:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":3100}},"rate_limits":null}}"#,
            #"{"timestamp":"2026-09-23T09:06:00.000Z","type":"event_msg","payload":{"type":"agent_message","message":"token_count is fine"}}"#,
            #"{"timestamp":"2026-09-23T09:07:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"turn_context"}]}}"#
        ].map { Data($0.utf8) }

        let parsed = lines.compactMap { CodexUsageLog.line(from: $0) }
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed.first, .model("gpt-5-codex"))

        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 10)))
        let summary = CodexUsageSummary.make(sessions: [parsed], now: now, calendar: calendar)
        XCTAssertEqual(summary.todayTokens, 3_100)
        XCTAssertEqual(summary.model, "gpt-5-codex")
        XCTAssertEqual(summary.contextTokens, 1_100)
        XCTAssertEqual(summary.contextWindow, 272_000)

        let primary = try XCTUnwrap(summary.primary)
        XCTAssertEqual(primary.title, "5-hour limit")
        XCTAssertEqual(primary.usedPercent, 12.5)
        XCTAssertEqual(primary.resetsAt, Date(timeIntervalSince1970: 1_790_164_800))

        let secondary = try XCTUnwrap(summary.secondary)
        XCTAssertEqual(secondary.title, "Weekly limit")
        XCTAssertEqual(secondary.resetsAt, calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 10, minute: 1)))

        let afterReset = CodexUsageSummary.make(sessions: [parsed], now: now.addingTimeInterval(60 * 60), calendar: calendar)
        XCTAssertNil(afterReset.secondary, "An expired reported percentage is not a current quota")
    }

    func testCodexActivityCountsSessionDeltasOnceAcrossDays() throws {
        let entries = [
            ("2026-09-22T23:50:00Z", 100),
            ("2026-09-23T00:10:00Z", 240),
            ("2026-09-23T00:11:00Z", 240)
        ].compactMap { stamp, total in
            CodexUsageLog.line(from: Data(#"{"timestamp":"\#(stamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":\#(total)},"last_token_usage":{"total_tokens":140}}}}"#.utf8))
        }
        let now = try XCTUnwrap(TimestampParser().date(from: "2026-09-23T12:00:00Z"))
        let summary = CodexUsageSummary.make(sessions: [entries], now: now, calendar: calendar)

        XCTAssertEqual(summary.dailyTokens[calendar.startOfDay(for: now.addingTimeInterval(-24 * 60 * 60))], 100)
        XCTAssertEqual(summary.dailyTokens[calendar.startOfDay(for: now)], 140)
        XCTAssertEqual(summary.todayTokens, 140)
    }

    func testActivityScanStartsOnMondayOfFiftySecondWeek() throws {
        let now = try XCTUnwrap(TimestampParser().date(from: "2026-09-23T12:00:00Z"))
        var sundayFirstCalendar = calendar
        sundayFirstCalendar.firstWeekday = 1
        var mondayFirstCalendar = calendar
        mondayFirstCalendar.firstWeekday = 2
        let currentWeek = try XCTUnwrap(mondayFirstCalendar.dateInterval(of: .weekOfYear, for: now)?.start)
        let oldestWeek = try XCTUnwrap(mondayFirstCalendar.date(byAdding: .weekOfYear, value: -51, to: currentWeek))
        XCTAssertEqual(AIUsageScanner.historyWeekCount, 52)
        XCTAssertEqual(
            AIUsageScanner.scanStart(now: now, calendar: sundayFirstCalendar),
            oldestWeek
        )
        XCTAssertEqual(mondayFirstCalendar.component(.weekday, from: oldestWeek), 2)
        XCTAssertEqual(mondayFirstCalendar.date(byAdding: .weekOfYear, value: 52, to: oldestWeek),
                       mondayFirstCalendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek))
    }

    func testScannerReadsRecentLogsUnderHome() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistAIUsageTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let now = Date()
        let entryDate = now.addingTimeInterval(-60)
        let stamp = ISO8601DateFormatter().string(from: entryDate)
        // Near midnight the entry can fall on the previous day.
        let isToday = Calendar.current.isDate(entryDate, inSameDayAs: now)

        let claudeDirectory = home.appendingPathComponent(".claude/projects/-Users-me-app", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try claudeLine(id: "m1", request: "r1", at: stamp)
            .write(to: claudeDirectory.appendingPathComponent("session.jsonl"))

        let codexDirectory = home.appendingPathComponent(".codex/sessions/2026/09/23", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let codexLog = #"{"timestamp":"\#(stamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":42},"model_context_window":1000},"rate_limits":null}}"#
        try Data(codexLog.utf8).write(to: codexDirectory.appendingPathComponent("rollout-1.jsonl"))

        let claude = try XCTUnwrap(AIUsageScanner.claude(home: home, now: now, calendar: .current))
        XCTAssertEqual(claude.today.total, isToday ? 1_160 : 0)
        XCTAssertNotNil(claude.activeBlock)

        let codex = try XCTUnwrap(AIUsageScanner.codex(home: home, now: now, calendar: .current))
        XCTAssertEqual(codex.todayTokens, isToday ? 42 : 0)

        let empty = home.appendingPathComponent("empty", isDirectory: true)
        XCTAssertNil(AIUsageScanner.claude(home: empty, now: now, calendar: .current))
        XCTAssertNil(AIUsageScanner.codex(home: empty, now: now, calendar: .current))
    }

    func testCachedScanReadsAppendedActivityAndReusesUnchangedFiles() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let now = Date()
        let stamp = ISO8601DateFormatter().string(from: now.addingTimeInterval(-60))
        let directory = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("session.jsonl")
        try claudeLine(id: "first", request: "one", at: stamp).write(to: file)

        var cache = AIUsageScanner.Cache()
        let first = try XCTUnwrap(cache.claude(home: home, now: now, calendar: calendar))
        XCTAssertEqual(first.dailyTokens[calendar.startOfDay(for: now.addingTimeInterval(-60))], 1_160)
        XCTAssertEqual(cache.claude(home: home, now: now, calendar: calendar), first)

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n".utf8) + claudeLine(id: "second", request: "two", at: stamp))
        try handle.close()
        let updated = try XCTUnwrap(cache.claude(home: home, now: now, calendar: calendar))
        XCTAssertEqual(updated.dailyTokens[calendar.startOfDay(for: now.addingTimeInterval(-60))], 2_320)
    }

    func testScannerRetainsOldestWeekAndSessionDeltasAcrossBoundary() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let now = try XCTUnwrap(TimestampParser().date(from: "2026-09-23T12:00:00Z"))
        let start = AIUsageScanner.scanStart(now: now, calendar: calendar)
        let before = ISO8601DateFormatter().string(from: start.addingTimeInterval(-60))
        let first = ISO8601DateFormatter().string(from: start)
        let second = ISO8601DateFormatter().string(from: start.addingTimeInterval(24 * 60 * 60))
        let claudeDirectory = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try [
            claudeLine(id: "before", request: "1", at: before),
            claudeLine(id: "first", request: "2", at: first),
            claudeLine(id: "second", request: "3", at: second)
        ].reduce(Data()) { $0 + $1 + Data("\n".utf8) }
            .write(to: claudeDirectory.appendingPathComponent("session.jsonl"))

        let codexDirectory = home.appendingPathComponent(".codex/sessions/2025/09/29")
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        let codexLines = [(before, 100), (first, 240), (second, 400)].map { stamp, total in
            #"{"timestamp":"\#(stamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":\#(total)}}}}"#
        }
        try Data(codexLines.joined(separator: "\n").utf8).write(to: codexDirectory.appendingPathComponent("rollout-1.jsonl"))

        let claude = try XCTUnwrap(AIUsageScanner.claude(home: home, now: now, calendar: calendar))
        XCTAssertNil(claude.dailyTokens[calendar.startOfDay(for: start.addingTimeInterval(-60))])
        XCTAssertEqual(claude.dailyTokens[start], 1_160)
        XCTAssertEqual(claude.dailyTokens[calendar.startOfDay(for: start.addingTimeInterval(24 * 60 * 60))], 1_160)

        var cache = AIUsageScanner.Cache()
        let codex = try XCTUnwrap(cache.codex(home: home, now: now, calendar: calendar))
        XCTAssertNil(codex.dailyTokens[calendar.startOfDay(for: start.addingTimeInterval(-60))])
        XCTAssertEqual(codex.dailyTokens[start], 140)
        XCTAssertEqual(codex.dailyTokens[calendar.startOfDay(for: start.addingTimeInterval(24 * 60 * 60))], 160)
        XCTAssertEqual(cache.codex(home: home, now: now, calendar: calendar), codex)

        let file = codexDirectory.appendingPathComponent("rollout-1.jsonl")
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\n".utf8) + Data(#"{"timestamp":"\#(second)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":500}}}}"#.utf8))
        try handle.close()
        let updated = try XCTUnwrap(cache.codex(home: home, now: now, calendar: calendar))
        XCTAssertEqual(updated.dailyTokens[calendar.startOfDay(for: start.addingTimeInterval(24 * 60 * 60))], 260)

        try FileManager.default.removeItem(at: file)
        XCTAssertTrue(try XCTUnwrap(cache.codex(home: home, now: now, calendar: calendar)).dailyTokens.isEmpty)
    }

    func testCachedCodexQuotaExpiresWithoutReparsingUnchangedFile() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = home.appendingPathComponent(".codex/sessions/2026/09/23")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = "2026-09-23T09:00:00Z"
        let now = try XCTUnwrap(TimestampParser().date(from: "2026-09-23T09:30:00Z"))
        let reset = Int(now.addingTimeInterval(30 * 60).timeIntervalSince1970)
        let line = #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":100}},"rate_limits":{"primary":{"used_percent":85,"window_minutes":300,"resets_at":\#(reset)}}}}"#
        try Data(line.utf8).write(to: directory.appendingPathComponent("rollout-1.jsonl"))

        var cache = AIUsageScanner.Cache()
        let before = try XCTUnwrap(cache.codex(home: home, now: now, calendar: calendar))
        XCTAssertEqual(before.primary?.usedPercent, 85)
        let after = try XCTUnwrap(cache.codex(home: home, now: now.addingTimeInterval(60 * 60), calendar: calendar))
        XCTAssertNil(after.primary)
        XCTAssertEqual(after.dailyTokens, before.dailyTokens)
    }

    @MainActor
    func testUsagePublishesRecentStatusBeforeFullHistory() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recentDate = Date().addingTimeInterval(-60)
        let olderDate = recentDate.addingTimeInterval(-14 * 24 * 60 * 60)
        let formatter = ISO8601DateFormatter()
        try claudeLine(id: "recent", request: "recent", at: formatter.string(from: recentDate))
            .write(to: directory.appendingPathComponent("recent.jsonl"))
        try claudeLine(id: "older", request: "older", at: formatter.string(from: olderDate))
            .write(to: directory.appendingPathComponent("older.jsonl"))

        let service = AIUsageService(homeDirectory: home)
        let recent = expectation(description: "Recent usage is available before the year scan")
        let history = expectation(description: "Year history finishes")
        let recentSubscription = service.$lastUpdated.compactMap { $0 }.first().sink { _ in
            XCTAssertFalse(service.isHistoryReady)
            XCTAssertEqual(service.claude?.dailyTokens[Calendar.current.startOfDay(for: recentDate)], 1_160)
            XCTAssertNil(service.claude?.dailyTokens[Calendar.current.startOfDay(for: olderDate)])
            recent.fulfill()
        }
        let historySubscription = service.$isHistoryReady.filter { $0 }.first().sink { _ in
            history.fulfill()
        }

        service.refresh()
        await fulfillment(of: [recent, history], timeout: 10)
        XCTAssertEqual(service.claude?.dailyTokens[Calendar.current.startOfDay(for: olderDate)], 1_160)
        withExtendedLifetime((recentSubscription, historySubscription)) {}
    }
}
