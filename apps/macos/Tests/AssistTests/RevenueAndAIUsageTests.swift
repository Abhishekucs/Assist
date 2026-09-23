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
            sale("b", 2_000, "USD", daysAgo: 3, provider: .polar),
            sale("c", 500, "EUR", daysAgo: 6),
            sale("d", 4_000, "USD", daysAgo: 20, provider: .dodo),
            sale("e", 9_000, "USD", daysAgo: 45)
        ], now: now, calendar: calendar)

        XCTAssertEqual(summary.totals[.today]?.amounts, ["USD": 1_000])
        XCTAssertEqual(summary.totals[.week]?.amounts, ["USD": 3_000, "EUR": 500])
        XCTAssertEqual(summary.totals[.week]?.currencies, ["USD", "EUR"])
        XCTAssertEqual(summary.totals[.month]?.amounts, ["USD": 7_000, "EUR": 500])
        XCTAssertEqual(summary.totals[.month]?.count, 4)
        XCTAssertEqual(summary.providerTotals[.dodo]?.amounts, ["USD": 4_000])
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
        XCTAssertEqual(afterReset.secondary?.usedPercent, 0, "A window past its reset time is empty")
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
}
