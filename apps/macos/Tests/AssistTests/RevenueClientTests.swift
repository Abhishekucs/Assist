import Foundation
import XCTest
@testable import Assist

final class RevenueClientTests: XCTestCase {
    func testEveryStripePageUsesTheCapturedAmountAPIContract() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StripeRevenueProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let transactions = try await RevenueClient(session: session).transactions(
            from: .stripe,
            key: "test-only",
            since: Date(timeIntervalSince1970: 1_790_000_000)
        )
        XCTAssertEqual(transactions.map(\.id), ["partial_capture", "refunded_capture"])
        XCTAssertEqual(transactions.map(\.amountMinor), [6000, 4500])
    }
}

final class RevenueExchangeRateClientTests: XCTestCase {
    func testRefreshFetchesOnlyRecentDaysAndRetainsHistoricalQuotes() async throws {
        HistoricalRatesProtocol.recorder.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HistoricalRatesProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = RevenueExchangeRateClient(session: session)
        let formatter = ISO8601DateFormatter()
        let since = try XCTUnwrap(formatter.date(from: "2026-09-01T12:00:00Z"))
        let through = try XCTUnwrap(formatter.date(from: "2026-09-29T12:00:00Z"))
        let earlierSale = RevenueTransaction(provider: .stripe, id: "earlier", amountMinor: 100,
                                             currency: "EUR", createdAt: try XCTUnwrap(formatter.date(from: "2026-09-05T12:00:00Z")))
        let recentSale = RevenueTransaction(provider: .dodo, id: "recent", amountMinor: 100,
                                            currency: "EUR", createdAt: try XCTUnwrap(formatter.date(from: "2026-09-28T12:00:00Z")))

        let initial = try await client.rates(for: ["EUR"], since: since, through: through)
        XCTAssertEqual(try initial.convert(recentSale, to: "USD").amountMinor, 125)

        let cached = try await client.rates(for: ["EUR"], since: since, through: through.addingTimeInterval(60))
        XCTAssertEqual(try cached.convert(recentSale, to: "USD").amountMinor, 125)

        let afterRateRefresh = through.addingTimeInterval(20 * 60)
        let refreshed = try await client.rates(for: ["EUR"], since: since, through: afterRateRefresh)
        XCTAssertEqual(try refreshed.convert(recentSale, to: "USD").amountMinor, 111)
        XCTAssertEqual(try refreshed.convert(earlierSale, to: "USD").amountMinor, 133)

        let withNewCurrency = try await client.rates(for: ["EUR", "UGX"], since: since, through: afterRateRefresh)
        let ugxSale = RevenueTransaction(provider: .stripe, id: "ugx", amountMinor: 400,
                                         currency: "UGX", createdAt: recentSale.createdAt)
        XCTAssertEqual(try withNewCurrency.convert(ugxSale, to: "USD").amountMinor, 10)
        XCTAssertEqual(try withNewCurrency.convert(earlierSale, to: "USD").amountMinor, 133)

        let requests = HistoricalRatesProtocol.recorder.urls
        XCTAssertEqual(requests.count, 3)
        let starts = requests.compactMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "from" })?.value }
        XCTAssertEqual(starts, ["2026-08-22", "2026-09-28", "2026-08-22"])
        let requestedCurrencies = requests.compactMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "quotes" })?.value }
        XCTAssertEqual(requestedCurrencies, ["EUR", "EUR", "UGX"])
    }

    func testEmptyFirstResponseDoesNotHideHistoricalRatesAfterRecovery() async throws {
        HistoricalRatesProtocol.recorder.reset(emptyFirst: true)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HistoricalRatesProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let client = RevenueExchangeRateClient(session: session)
        let formatter = ISO8601DateFormatter()
        let since = try XCTUnwrap(formatter.date(from: "2026-09-01T12:00:00Z"))
        let through = try XCTUnwrap(formatter.date(from: "2026-09-29T12:00:00Z"))
        let sale = RevenueTransaction(provider: .stripe, id: "eur", amountMinor: 100,
                                      currency: "EUR", createdAt: try XCTUnwrap(formatter.date(from: "2026-09-28T12:00:00Z")))

        let unavailable = try await client.rates(for: ["EUR"], since: since, through: through)
        XCTAssertThrowsError(try unavailable.convert(sale, to: "USD"))
        let recovered = try await client.rates(for: ["EUR"], since: since, through: through)
        XCTAssertEqual(try recovered.convert(sale, to: "USD").amountMinor, 111)

        let starts = HistoricalRatesProtocol.recorder.urls.compactMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "from" })?.value
        }
        XCTAssertEqual(starts, ["2026-08-22", "2026-08-22"])
    }
}

final class RevenueServiceRefreshTests: XCTestCase {
    func testUGXUsesFrankfurterRateOutsideTheECBFeed() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MixedCurrencyRevenueProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let now = Date()
        let rates = try await RevenueExchangeRateClient(session: session).rates(
            for: ["USD", "UGX"], since: now.addingTimeInterval(-86_400), through: now
        )
        let sale = RevenueTransaction(provider: .stripe, id: "ugx", amountMinor: 400,
                                      currency: "UGX", createdAt: now)
        XCTAssertEqual(try rates.convert(sale, to: "USD").amountMinor, 10)
    }

    @MainActor
    func testDodoSaleInEURAppearsInCombinedUSDTotals() throws {
        let suite = "Assist.RevenueConversionTests.\(UUID().uuidString)"
        let keys = KeychainSecretStore(service: suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        try keys.setSecret("test-only", for: RevenueProvider.dodo.rawValue)
        defer {
            keys.removeSecret(for: RevenueProvider.dodo.rawValue)
            defaults.removePersistentDomain(forName: suite)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MixedCurrencyRevenueProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let service = RevenueService(
            keys: keys,
            client: RevenueClient(session: session),
            exchangeRateClient: RevenueExchangeRateClient(session: session),
            defaults: defaults
        )
        service.start()
        runMainLoop(until: { service.lastUpdated != nil })
        service.stop()

        XCTAssertNil(service.conversionError)
        XCTAssertEqual(service.selectedCurrency, "USD")
        XCTAssertEqual(service.saleCurrencies, ["USD", "EUR"])
        XCTAssertEqual(service.summary?.totals[.week]?.amounts, ["USD": 6556])
        XCTAssertEqual(service.summary?.providerTotals[.dodo]?.amounts, ["USD": 6556])

        service.selectCurrency("EUR")
        XCTAssertEqual(service.summary?.totals[.week]?.amounts, ["EUR": 5900])
        XCTAssertEqual(defaults.string(forKey: "modules.revenue.currency"), "EUR")
    }

    @MainActor
    func testReopeningRevenueFetchesNewPaymentBeforePollingIntervalExpires() throws {
        let serviceName = "Assist.RevenueRefreshTests.\(UUID().uuidString)"
        let keys = KeychainSecretStore(service: serviceName)
        try keys.setSecret("test-only", for: RevenueProvider.stripe.rawValue)
        defer { keys.removeSecret(for: RevenueProvider.stripe.rawValue) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdatingStripeRevenueProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        UpdatingStripeRevenueProtocol.counter.reset()

        let service = RevenueService(keys: keys, client: RevenueClient(session: session))
        service.start()
        runMainLoop(until: { service.lastUpdated != nil })
        XCTAssertEqual(service.summary?.totals[.month]?.amounts["USD"], 100)

        service.stop()
        service.start()
        runMainLoop(until: { UpdatingStripeRevenueProtocol.counter.value >= 2 && !service.isRefreshing })
        service.stop()

        XCTAssertEqual(UpdatingStripeRevenueProtocol.counter.value, 2)
        XCTAssertEqual(service.summary?.totals[.month]?.amounts["USD"], 300)
    }

    @MainActor
    private func runMainLoop(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }
}

private final class MixedCurrencyRevenueProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let json: String
        switch request.url?.host {
        case "live.dodopayments.com":
            XCTAssertEqual(request.url?.path, "/payments")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only")
            let yesterday = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86_400))
            json = """
            {"items":[
              {"payment_id":"usd","created_at":"\(yesterday)","currency":"USD","total_amount":6000,"status":"succeeded"},
              {"payment_id":"eur","created_at":"\(yesterday)","currency":"EUR","total_amount":500,"status":"succeeded"}
            ]}
            """
        case "api.frankfurter.dev":
            XCTAssertEqual(request.url?.path, "/v2/rates")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertNil(query.first { $0.name == "providers" })
            let quote = query.first { $0.name == "quotes" }?.value
            XCTAssertTrue(quote == "EUR" || quote == "UGX")
            let yesterday = String(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86_400)).prefix(10))
            let rate = quote == "UGX" ? "4000" : "0.9"
            json = "[{\"date\":\"\(yesterday)\",\"base\":\"USD\",\"quote\":\"\(quote ?? "")\",\"rate\":\(rate)}]"
        default:
            XCTFail("Unexpected revenue request: \(request.url?.host ?? "unknown")")
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }
    func reset() { lock.withLock { count = 0 } }
    func next() -> Int { lock.withLock { count += 1; return count } }
}

private final class RateRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedURLs: [URL] = []
    private var emptyFirst = false

    var urls: [URL] { lock.withLock { recordedURLs } }
    var shouldReturnEmptyFirst: Bool { lock.withLock { emptyFirst } }
    func reset(emptyFirst: Bool = false) { lock.withLock { recordedURLs = []; self.emptyFirst = emptyFirst } }
    func record(_ url: URL) -> Int { lock.withLock { recordedURLs.append(url); return recordedURLs.count } }
}

private final class HistoricalRatesProtocol: URLProtocol, @unchecked Sendable {
    static let recorder = RateRequestRecorder()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let requestNumber = Self.recorder.record(request.url!)
        let quote = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "quotes" })?.value
        let json: String
        if requestNumber == 1 && Self.recorder.shouldReturnEmptyFirst {
            json = "[]"
        } else if quote == "UGX" {
            json = "[{\"date\":\"2026-09-28\",\"base\":\"USD\",\"quote\":\"UGX\",\"rate\":4000}]"
        } else if requestNumber == 1 {
            json = """
            [{"date":"2026-09-05","base":"USD","quote":"EUR","rate":0.75},
             {"date":"2026-09-28","base":"USD","quote":"EUR","rate":0.8}]
            """
        } else {
            json = "[{\"date\":\"2026-09-28\",\"base\":\"USD\",\"quote\":\"EUR\",\"rate\":0.9}]"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class UpdatingStripeRevenueProtocol: URLProtocol, @unchecked Sendable {
    static let counter = RequestCounter()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let number = Self.counter.next()
        let created = Int(Date().timeIntervalSince1970)
        let first = """
        {"id":"first","amount_captured":100,"amount_refunded":0,"currency":"usd","created":\(created),"paid":true,"status":"succeeded"}
        """
        let second = """
        {"id":"second","amount_captured":200,"amount_refunded":0,"currency":"usd","created":\(created),"paid":true,"status":"succeeded"}
        """
        let payments = number > 1 ? [first, second] : [first]
        let json = "{\"has_more\":false,\"data\":[\(payments.joined(separator: ","))]}"
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Intercepts every request; this test never contacts Stripe or uses real keys.
private final class StripeRevenueProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        XCTAssertEqual(request.url?.host, "api.stripe.com")
        XCTAssertEqual(request.url?.path, "/v1/charges")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Stripe-Version"), "2025-03-31.basil")
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "created[gte]" }?.value, "1790000000")
        let cursor = query.first { $0.name == "starting_after" }?.value
        let json: String
        if cursor == nil {
            json = #"{"has_more":true,"data":[{"id":"partial_capture","amount":10000,"amount_captured":6000,"amount_refunded":0,"currency":"usd","created":1790157600,"paid":true,"status":"succeeded"}]}"#
        } else {
            XCTAssertEqual(cursor, "partial_capture")
            json = #"{"has_more":false,"data":[{"id":"refunded_capture","amount":10000,"amount_captured":6000,"amount_refunded":1500,"currency":"usd","created":1790157600,"paid":true,"status":"succeeded"}]}"#
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
