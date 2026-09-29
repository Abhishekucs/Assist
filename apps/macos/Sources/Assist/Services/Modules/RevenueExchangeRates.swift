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
            createdAt: transaction.createdAt,
            wasConverted: true
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

actor RevenueExchangeRateClient {
    private static let recentRefreshInterval: TimeInterval = 15 * 60
    private let session: URLSession
    private var cachedQuotes: [String: [String: RevenueExchangeRates.Quote]] = [:]
    private var fetchedFrom: [String: String] = [:]
    private var fetchedThrough: [String: Date] = [:]
    private var lastCheckedAt: [String: Date] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func rates(for currencies: Set<String>, since: Date, through: Date) async throws -> RevenueExchangeRates {
        let quotes = currencies.subtracting(["USD"])
        guard !quotes.isEmpty else { return try RevenueExchangeRates(quotes: []) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // Include the prior published rate for weekends and market holidays.
        let start = calendar.date(byAdding: .day, value: -10, to: since) ?? since
        let firstDay = RevenueExchangeRates.utcDay(start)
        let lastDay = RevenueExchangeRates.utcDay(through)
        let recentDay = RevenueExchangeRates.utcDay(
            calendar.date(byAdding: .day, value: -1, to: through) ?? through
        )

        var currenciesByStart: [String: [String]] = [:]
        for quote in quotes.sorted() {
            let requestStart: String
            if let cachedStart = fetchedFrom[quote], cachedStart <= firstDay,
               let previousThrough = fetchedThrough[quote] {
                if RevenueExchangeRates.utcDay(previousThrough) == lastDay,
                   let checkedAt = lastCheckedAt[quote],
                   (0..<Self.recentRefreshInterval).contains(through.timeIntervalSince(checkedAt)) {
                    continue
                }
                let nextUnfetched = RevenueExchangeRates.utcDay(
                    calendar.date(byAdding: .day, value: 1, to: previousThrough) ?? previousThrough
                )
                // Recheck only the latest two UTC days for late publications
                // or revisions; older published quotes stay in memory.
                requestStart = max(firstDay, min(nextUnfetched, recentDay))
            } else {
                requestStart = firstDay
            }
            currenciesByStart[requestStart, default: []].append(quote)
        }

        for requestStart in currenciesByStart.keys.sorted() {
            guard let requestQuotes = currenciesByStart[requestStart] else { continue }
            let items = try await fetchQuotes(requestQuotes, from: requestStart, through: lastDay)
            guard items.allSatisfy({ $0.base == "USD" && $0.rate > 0 && requestQuotes.contains($0.quote) }) else {
                throw RevenueExchangeError.unavailable
            }
            for item in items {
                cachedQuotes[item.quote, default: [:]][item.date] = item
            }
            for quote in requestQuotes {
                // An empty first response does not establish historical
                // coverage; retry the full window when rates return.
                guard cachedQuotes[quote]?.isEmpty == false else { continue }
                fetchedFrom[quote] = min(fetchedFrom[quote] ?? requestStart, requestStart)
                fetchedThrough[quote] = max(fetchedThrough[quote] ?? through, through)
                lastCheckedAt[quote] = through
            }
        }

        let available = quotes.sorted().flatMap { quote in
            Array(cachedQuotes[quote, default: [:]].values)
        }
        return try RevenueExchangeRates(quotes: available)
    }

    private func fetchQuotes(_ quotes: [String], from firstDay: String, through lastDay: String) async throws -> [RevenueExchangeRates.Quote] {
        var components = URLComponents(string: "https://api.frankfurter.dev/v2/rates")!
        components.queryItems = [
            URLQueryItem(name: "from", value: firstDay),
            URLQueryItem(name: "to", value: lastDay),
            URLQueryItem(name: "base", value: "USD"),
            URLQueryItem(name: "quotes", value: quotes.joined(separator: ","))
        ]
        guard let url = components.url else { throw RevenueExchangeError.unavailable }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw RevenueExchangeError.unavailable
        }
        return try JSONDecoder().decode([RevenueExchangeRates.Quote].self, from: data)
    }
}
