import Foundation

enum RevenueExchangeError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Exchange rates unavailable. Revenue totals cannot be combined safely."
    }
}

/// Daily Frankfurter rates, quoted as units of each currency per one USD.
/// A sale uses the latest published rate on or before its UTC payment date.
struct RevenueExchangeRates: Sendable {
    struct Quote: Decodable, Sendable {
        let date: String
        let base: String
        let quote: String
        let rate: Decimal
    }

    private let rates: [String: [Quote]]

    init(quotes: [Quote]) throws {
        guard quotes.allSatisfy({ $0.base == "USD" && $0.rate > 0 }) else {
            throw RevenueExchangeError.unavailable
        }
        rates = Dictionary(grouping: quotes, by: \.quote)
            .mapValues { $0.sorted { $0.date < $1.date } }
    }

    func convert(_ transaction: RevenueTransaction, to currency: String) throws -> RevenueTransaction {
        guard transaction.currency != currency else { return transaction }

        let date = Self.utcDay(transaction.createdAt)
        let sourceRate = try rate(for: transaction.currency, on: date)
        let targetRate = try rate(for: currency, on: date)
        let sourceScale = pow(Decimal(10), MoneyFormatting.minorUnitDigits(for: transaction.currency))
        let targetScale = pow(Decimal(10), MoneyFormatting.minorUnitDigits(for: currency))
        var result = Decimal(transaction.amountMinor) / sourceScale / sourceRate * targetRate * targetScale
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 0, .plain)
        let number = NSDecimalNumber(decimal: rounded)
        guard number != .notANumber,
              number.compare(NSNumber(value: Int64.max)) != .orderedDescending,
              number.compare(NSNumber(value: Int64.min)) != .orderedAscending else {
            throw RevenueExchangeError.unavailable
        }
        return RevenueTransaction(
            provider: transaction.provider,
            id: transaction.id,
            amountMinor: number.int64Value,
            currency: currency,
            createdAt: transaction.createdAt
        )
    }

    private func rate(for currency: String, on date: String) throws -> Decimal {
        if currency == "USD" { return 1 }
        guard let quote = rates[currency]?.last(where: { $0.date <= date }) else {
            throw RevenueExchangeError.unavailable
        }
        return quote.rate
    }

    static func utcDay(_ date: Date) -> String {
        String(ISO8601DateFormatter().string(from: date).prefix(10))
    }
}

struct RevenueExchangeRateClient: Sendable {
    var session: URLSession = .shared

    func rates(for currencies: Set<String>, since: Date, through: Date) async throws -> RevenueExchangeRates {
        let quotes = currencies.subtracting(["USD"])
        guard !quotes.isEmpty else { return try RevenueExchangeRates(quotes: []) }

        // Include the prior published rate for weekends and market holidays.
        let start = Calendar(identifier: .gregorian).date(byAdding: .day, value: -10, to: since) ?? since
        var components = URLComponents(string: "https://api.frankfurter.dev/v2/rates")!
        components.queryItems = [
            URLQueryItem(name: "from", value: RevenueExchangeRates.utcDay(start)),
            URLQueryItem(name: "to", value: RevenueExchangeRates.utcDay(through)),
            URLQueryItem(name: "base", value: "USD"),
            URLQueryItem(name: "quotes", value: quotes.sorted().joined(separator: ","))
        ]
        guard let url = components.url else { throw RevenueExchangeError.unavailable }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw RevenueExchangeError.unavailable
        }
        let items = try JSONDecoder().decode([RevenueExchangeRates.Quote].self, from: data)
        return try RevenueExchangeRates(quotes: items)
    }
}
