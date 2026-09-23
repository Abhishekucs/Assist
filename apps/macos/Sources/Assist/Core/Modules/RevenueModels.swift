import Foundation

enum RevenueProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case stripe
    case polar
    case dodo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stripe: "Stripe"
        case .polar: "Polar"
        case .dodo: "Dodo Payments"
        }
    }

    /// The narrowest key that works, shown beside the key field in Settings.
    var keyHint: String {
        switch self {
        case .stripe: "A restricted key (rk_live_…) with read access to Charges."
        case .polar: "An organization access token with the orders:read scope."
        case .dodo: "A live-mode API key. Assist only lists payments."
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .stripe: "rk_live_…"
        case .polar: "polar_oat_…"
        case .dodo: "Dodo API key"
        }
    }
}

/// One successful sale, in the currency's smallest unit (cents for USD, yen for JPY).
struct RevenueTransaction: Equatable, Sendable {
    let provider: RevenueProvider
    let id: String
    let amountMinor: Int64
    /// Upper-case ISO 4217 code.
    let currency: String
    let createdAt: Date
}

/// Sales added up per currency, since providers never convert between them.
struct RevenueTotals: Equatable, Sendable {
    private(set) var amounts: [String: Int64] = [:]
    private(set) var count = 0

    mutating func add(_ transaction: RevenueTransaction) {
        amounts[transaction.currency, default: 0] += transaction.amountMinor
        count += 1
    }

    /// Currencies with the largest total first.
    var currencies: [String] {
        amounts.keys.sorted { lhs, rhs in
            let left = amounts[lhs] ?? 0
            let right = amounts[rhs] ?? 0
            return left == right ? lhs < rhs : left > right
        }
    }
}

enum RevenueWindow: CaseIterable, Identifiable, Sendable {
    case today
    case week
    case month

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        }
    }

    /// Whole local days, counting today.
    var dayCount: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }

    func start(now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
    }
}

struct RevenueSummary: Equatable, Sendable {
    /// The longest window fetched from the providers.
    static let fetchWindow = RevenueWindow.month

    var totals: [RevenueWindow: RevenueTotals] = [:]
    /// Each provider's total over `fetchWindow`.
    var providerTotals: [RevenueProvider: RevenueTotals] = [:]
    var dailyTotals: [Date: RevenueTotals] = [:]

    static func make(from transactions: [RevenueTransaction], now: Date, calendar: Calendar) -> RevenueSummary {
        var summary = RevenueSummary()
        for window in RevenueWindow.allCases {
            let start = window.start(now: now, calendar: calendar)
            var totals = RevenueTotals()
            for transaction in transactions where transaction.createdAt >= start && transaction.createdAt <= now {
                totals.add(transaction)
            }
            summary.totals[window] = totals
        }

        let start = fetchWindow.start(now: now, calendar: calendar)
        for transaction in transactions where transaction.createdAt >= start && transaction.createdAt <= now {
            summary.providerTotals[transaction.provider, default: RevenueTotals()].add(transaction)
            let day = calendar.startOfDay(for: transaction.createdAt)
            summary.dailyTotals[day, default: RevenueTotals()].add(transaction)
        }
        return summary
    }

    func dailyAmounts(for currency: String, now: Date, calendar: Calendar) -> [RevenueDailyAmount] {
        let start = Self.fetchWindow.start(now: now, calendar: calendar)
        return (0..<Self.fetchWindow.dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return RevenueDailyAmount(day: day, amountMinor: dailyTotals[day]?.amounts[currency] ?? 0)
        }
    }
}

struct RevenueDailyAmount: Equatable, Sendable {
    let day: Date
    let amountMinor: Int64
}

enum MoneyFormatting {
    /// Decimal places of a currency's minor unit, as payment APIs count amounts.
    static func minorUnitDigits(for currency: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.maximumFractionDigits
    }

    static func format(minor: Int64, currency: String, locale: Locale = .current) -> String {
        let digits = minorUnitDigits(for: currency)
        let major = Decimal(minor) / pow(Decimal(10), digits)
        return major.formatted(
            .currency(code: currency)
                .locale(locale)
                .precision(.fractionLength(digits))
        )
    }
}

/// Decodes the list endpoints Assist reads, and keeps only settled sales.
enum RevenueParsing {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: Stripe — GET /v1/charges

    struct StripeChargesPage: Decodable, Sendable {
        struct Charge: Decodable, Sendable {
            let id: String
            let amount: Int64
            let amountRefunded: Int64
            let currency: String
            let created: Int64
            let paid: Bool
            let status: String
        }

        let data: [Charge]
        let hasMore: Bool
    }

    /// Succeeded, paid charges, less anything refunded.
    static func transactions(from page: StripeChargesPage) -> [RevenueTransaction] {
        page.data.compactMap { charge in
            guard charge.paid, charge.status == "succeeded" else { return nil }
            let amount = charge.amount - charge.amountRefunded
            guard amount > 0 else { return nil }
            return RevenueTransaction(
                provider: .stripe,
                id: charge.id,
                amountMinor: amount,
                currency: charge.currency.uppercased(),
                createdAt: Date(timeIntervalSince1970: TimeInterval(charge.created))
            )
        }
    }

    // MARK: Polar — GET /v1/orders/

    struct PolarOrdersPage: Decodable, Sendable {
        struct Order: Decodable, Sendable {
            let id: String
            let createdAt: String
            let paid: Bool
            /// After discounts, before tax.
            let netAmount: Int64
            let refundedAmount: Int64
            let refundedTaxAmount: Int64?
            let currency: String
        }

        struct Pagination: Decodable, Sendable {
            let totalCount: Int
            let maxPage: Int
        }

        let items: [Order]
        let pagination: Pagination
    }

    /// Paid orders at their net amount (before tax), less the net part of any refund.
    static func transactions(from page: PolarOrdersPage) -> [RevenueTransaction] {
        let timestamps = TimestampParser()
        return page.items.compactMap { order in
            guard order.paid, let createdAt = timestamps.date(from: order.createdAt) else { return nil }
            let refundedNet = max(order.refundedAmount - (order.refundedTaxAmount ?? 0), 0)
            let amount = order.netAmount - refundedNet
            guard amount > 0 else { return nil }
            return RevenueTransaction(
                provider: .polar,
                id: order.id,
                amountMinor: amount,
                currency: order.currency.uppercased(),
                createdAt: createdAt
            )
        }
    }

    // MARK: Dodo Payments — GET /payments

    struct DodoPaymentsPage: Decodable, Sendable {
        struct Payment: Decodable, Sendable {
            let paymentId: String
            let createdAt: String
            let currency: String
            let totalAmount: Int64
            let status: String?
            let refundStatus: String?
        }

        let items: [Payment]
    }

    /// Succeeded payments that were not fully refunded.
    static func transactions(from page: DodoPaymentsPage) -> [RevenueTransaction] {
        let timestamps = TimestampParser()
        return page.items.compactMap { payment in
            guard payment.status == "succeeded",
                  payment.refundStatus != "full",
                  payment.totalAmount > 0,
                  let createdAt = timestamps.date(from: payment.createdAt) else { return nil }
            return RevenueTransaction(
                provider: .dodo,
                id: payment.paymentId,
                amountMinor: payment.totalAmount,
                currency: payment.currency.uppercased(),
                createdAt: createdAt
            )
        }
    }
}

/// Reads RFC 3339 timestamps with or without fractional seconds, including
/// the microsecond precision some APIs and logs use. Reuse one parser for
/// many timestamps; it is not shared between threads.
final class TimestampParser {
    private let withFraction: ISO8601DateFormatter
    private let plain: ISO8601DateFormatter

    init() {
        withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
    }

    func date(from string: String) -> Date? {
        if let date = withFraction.date(from: string) ?? plain.date(from: string) {
            return date
        }

        // Keep milliseconds from longer fractions the formatter rejects.
        guard let dot = string.firstIndex(of: "."),
              let zone = string[dot...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) else {
            return nil
        }
        let fraction = string[string.index(after: dot)..<zone].prefix(3)
        let milliseconds = fraction + String(repeating: "0", count: 3 - fraction.count)
        return withFraction.date(from: "\(string[..<dot]).\(milliseconds)\(string[zone...])")
    }
}
