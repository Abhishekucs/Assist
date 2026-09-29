import Foundation

enum RevenueError: LocalizedError, Equatable {
    case rejectedKey
    case http(Int)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .rejectedKey: "Key was rejected. Check it has read access."
        case let .http(status): "Request failed (HTTP \(status))."
        case .unexpectedResponse: "Unexpected response."
        }
    }
}

/// Reads the last 30 days of sales from each connected provider. Keys live in
/// the Keychain and are sent only to their own provider over HTTPS. Sampling
/// happens only while the Revenue module is on screen.
@MainActor
final class RevenueService: ObservableObject, VisibleModuleService {
    static let refreshInterval: TimeInterval = 60
    static let defaultCurrency = "USD"
    private static let currencyKey = "modules.revenue.currency"

    @Published private(set) var connectedProviders: [RevenueProvider] = []
    @Published private(set) var summary: RevenueSummary?
    @Published private(set) var errors: [RevenueProvider: String] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var selectedCurrency: String
    @Published private(set) var saleCurrencies: Set<String> = []
    @Published private(set) var conversionError: String?

    private let keys: KeychainSecretStore
    private let client: RevenueClient
    private let exchangeRateClient: RevenueExchangeRateClient
    private let defaults: UserDefaults
    private var sourceTransactions: [RevenueTransaction] = []
    private var exchangeRates: RevenueExchangeRates?
    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?
    private var viewerCount = 0

    init(
        keys: KeychainSecretStore = KeychainSecretStore(service: "\(AppIdentity.bundleIdentifier).revenue"),
        client: RevenueClient = RevenueClient(),
        exchangeRateClient: RevenueExchangeRateClient = RevenueExchangeRateClient(),
        defaults: UserDefaults = .standard
    ) {
        self.keys = keys
        self.client = client
        self.exchangeRateClient = exchangeRateClient
        self.defaults = defaults
        selectedCurrency = defaults.string(forKey: Self.currencyKey) ?? Self.defaultCurrency
        connectedProviders = RevenueProvider.allCases.filter { keys.hasSecret(for: $0.rawValue) }
    }

    func selectCurrency(_ currency: String) {
        guard selectedCurrency != currency else { return }
        selectedCurrency = currency
        defaults.set(currency, forKey: Self.currencyKey)
        guard exchangeRates != nil else {
            if !connectedProviders.isEmpty, refreshTask == nil { refresh(force: true) }
            return
        }
        do {
            try updateSummary(now: lastUpdated ?? Date())
        } catch {
            summary = nil
            conversionError = error.localizedDescription
            refresh(force: true)
        }
    }

    func isConnected(_ provider: RevenueProvider) -> Bool {
        connectedProviders.contains(provider)
    }

    func saveKey(_ key: String, for provider: RevenueProvider) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try keys.setSecret(trimmed, for: provider.rawValue)
        connectedProviders = RevenueProvider.allCases.filter { $0 == provider || connectedProviders.contains($0) }
        errors[provider] = nil
        DebugLogger.log("modules.revenue.key.saved", ["provider": provider.rawValue])
        restartRefresh()
    }

    func removeKey(for provider: RevenueProvider) {
        keys.removeSecret(for: provider.rawValue)
        connectedProviders.removeAll { $0 == provider }
        errors[provider] = nil
        sourceTransactions = []
        exchangeRates = nil
        saleCurrencies = []
        conversionError = nil
        summary = nil
        DebugLogger.log("modules.revenue.key.removed", ["provider": provider.rawValue])
        restartRefresh()
    }

    /// Starts refreshing for a view that shows revenue. Balanced by `stop()`.
    func start() {
        viewerCount += 1
        guard timer == nil else { return }
        refresh(force: true)
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(force: true)
            }
        }
        timer.tolerance = 10
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        viewerCount = max(viewerCount - 1, 0)
        guard viewerCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func restartRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        refresh(force: true)
    }

    /// Fetches again unless a refresh is running or, without `force`, the
    /// last one is recent.
    func refresh(force: Bool) {
        guard refreshTask == nil else { return }
        if !force, let lastUpdated, Date().timeIntervalSince(lastUpdated) < Self.refreshInterval {
            return
        }

        let credentials = connectedProviders.compactMap { provider in
            keys.secret(for: provider.rawValue).map { (provider, $0) }
        }
        guard !credentials.isEmpty else {
            summary = nil
            errors = [:]
            return
        }

        let now = Date()
        let since = RevenueSummary.fetchWindow.start(now: now, calendar: .current)
        let client = client
        let exchangeRateClient = exchangeRateClient
        isRefreshing = true
        conversionError = nil

        refreshTask = Task {
            var transactions: [RevenueTransaction] = []
            var failures: [RevenueProvider: String] = [:]
            for (provider, key) in credentials {
                guard !Task.isCancelled else { return }
                do {
                    transactions += try await client.transactions(from: provider, key: key, since: since)
                } catch {
                    guard !Task.isCancelled else { return }
                    failures[provider] = error as? RevenueError == .rejectedKey
                        ? provider.rejectedKeyMessage
                        : error.localizedDescription
                    DebugLogger.log("modules.revenue.fetch.error", [
                        "provider": provider.rawValue,
                        "description": error.localizedDescription
                    ])
                }
            }

            guard !Task.isCancelled else { return }
            let completedAt = Date()
            let currencies = Set(transactions.map(\.currency))
            do {
                var rateCurrency = self.selectedCurrency
                var requiredRates = currencies.allSatisfy { $0 == rateCurrency }
                    ? Set<String>()
                    : currencies.union([rateCurrency])
                var rates = try await exchangeRateClient.rates(
                    for: requiredRates,
                    since: since,
                    through: completedAt
                )
                while !Task.isCancelled && self.selectedCurrency != rateCurrency {
                    rateCurrency = self.selectedCurrency
                    requiredRates = currencies.allSatisfy { $0 == rateCurrency }
                        ? Set<String>()
                        : currencies.union([rateCurrency])
                    rates = try await exchangeRateClient.rates(
                        for: requiredRates,
                        since: since,
                        through: completedAt
                    )
                }
                guard !Task.isCancelled else { return }
                self.sourceTransactions = transactions
                self.exchangeRates = rates
                self.saleCurrencies = currencies
                try self.updateSummary(now: completedAt)
            } catch {
                guard !Task.isCancelled else { return }
                self.sourceTransactions = []
                self.exchangeRates = nil
                self.saleCurrencies = []
                self.summary = nil
                self.conversionError = RevenueExchangeError.unavailable.localizedDescription
                DebugLogger.log("modules.revenue.exchange.error", ["description": error.localizedDescription])
            }
            self.errors = failures
            self.lastUpdated = completedAt
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    private func updateSummary(now: Date) throws {
        guard let exchangeRates else { throw RevenueExchangeError.unavailable }
        let converted = try sourceTransactions.map { try exchangeRates.convert($0, to: selectedCurrency) }
        summary = RevenueSummary.make(from: converted, now: now, calendar: .current)
        conversionError = nil
    }
}

/// The HTTP calls behind the Revenue module: one list endpoint per provider,
/// followed page by page back to `since`.
struct RevenueClient: Sendable {
    /// Keeps a busy account from paging without end; 20 pages × 100 sales.
    static let maxPages = 20
    static let pageSize = 100
    // This contract excludes released authorizations from amount_refunded.
    // Pin it rather than inheriting each account's default API version.
    static let stripeAPIVersion = "2025-03-31.basil"

    var session: URLSession = .shared

    func transactions(from provider: RevenueProvider, key: String, since: Date) async throws -> [RevenueTransaction] {
        switch provider {
        case .stripe:
            return try await stripeTransactions(key: key, since: since)
        case .polar:
            return try await polarTransactions(key: key, since: since)
        case .dodo:
            return try await dodoTransactions(key: key, since: since)
        }
    }

    private func stripeTransactions(key: String, since: Date) async throws -> [RevenueTransaction] {
        var transactions: [RevenueTransaction] = []
        var startingAfter: String?

        for _ in 0..<Self.maxPages {
            var components = URLComponents(string: "https://api.stripe.com/v1/charges")!
            components.queryItems = [
                URLQueryItem(name: "limit", value: "\(Self.pageSize)"),
                URLQueryItem(name: "created[gte]", value: "\(Int(since.timeIntervalSince1970))")
            ] + (startingAfter.map { [URLQueryItem(name: "starting_after", value: $0)] } ?? [])

            let page = try await get(
                RevenueParsing.StripeChargesPage.self,
                from: components,
                key: key,
                headers: ["Stripe-Version": Self.stripeAPIVersion]
            )
            transactions += RevenueParsing.transactions(from: page)
            guard page.hasMore, let last = page.data.last else { break }
            startingAfter = last.id
        }
        return transactions
    }

    private func polarTransactions(key: String, since: Date) async throws -> [RevenueTransaction] {
        var transactions: [RevenueTransaction] = []
        let timestamps = TimestampParser()

        for page in 1...Self.maxPages {
            var components = URLComponents(string: "https://api.polar.sh/v1/orders/")!
            components.queryItems = [
                URLQueryItem(name: "limit", value: "\(Self.pageSize)"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "sorting", value: "-created_at")
            ]

            let response = try await get(RevenueParsing.PolarOrdersPage.self, from: components, key: key)
            transactions += RevenueParsing.transactions(from: response).filter { $0.createdAt >= since }

            // Orders arrive newest first, so a page reaching past `since` is the last one needed.
            let oldest = response.items.last.flatMap { timestamps.date(from: $0.createdAt) }
            guard page < response.pagination.maxPage, let oldest, oldest >= since else { break }
        }
        return transactions
    }

    private func dodoTransactions(key: String, since: Date) async throws -> [RevenueTransaction] {
        var transactionsByID: [String: RevenueTransaction] = [:]
        let createdAfter = ISO8601DateFormatter().string(from: since)

        for pageNumber in 0..<Self.maxPages {
            var components = URLComponents(string: "https://live.dodopayments.com/payments")!
            components.queryItems = [
                URLQueryItem(name: "page_size", value: "\(Self.pageSize)"),
                URLQueryItem(name: "page_number", value: "\(pageNumber)"),
                URLQueryItem(name: "created_at_gte", value: createdAfter),
                URLQueryItem(name: "status", value: "succeeded")
            ]

            let page = try await get(RevenueParsing.DodoPaymentsPage.self, from: components, key: key)
            for transaction in RevenueParsing.transactions(from: page) {
                transactionsByID[transaction.id] = transaction
            }
            guard page.items.count == Self.pageSize else { break }
        }
        return Array(transactionsByID.values)
    }

    private func get<Response: Decodable>(
        _ type: Response.Type,
        from components: URLComponents,
        key: String,
        headers: [String: String] = [:]
    ) async throws -> Response {
        guard let url = components.url else { throw RevenueError.unexpectedResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RevenueError.unexpectedResponse }
        switch http.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw RevenueError.rejectedKey
        default:
            throw RevenueError.http(http.statusCode)
        }

        do {
            return try RevenueParsing.decoder().decode(type, from: data)
        } catch {
            throw RevenueError.unexpectedResponse
        }
    }
}
