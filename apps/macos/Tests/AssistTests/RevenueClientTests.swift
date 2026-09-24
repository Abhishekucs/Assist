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
