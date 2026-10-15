import Combine
import Foundation

@MainActor
final class PositionStore: ObservableObject {
    @Published private(set) var positions: [PositionItem] = []
    @Published private(set) var connectionState: ConnectionState = .notConfigured
    @Published private(set) var marketStreamState: MarketStreamState = .disconnected
    @Published private(set) var marketQuotes: [MarketQuote] = []
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var scenario: MockScenario = .one
    @Published private(set) var isUsingRealData = false
    @Published private(set) var lastError: String?

    private var restClient: BinanceRESTClient?
    private var currentCredentials: APICredentials?
    private let marketStream = BinanceMarketStreamService()
    private var userDataStream: BinanceUserDataStreamService?
    private var snapshotDebounceTask: Task<Void, Never>?
    private var snapshotRefreshTask: Task<Void, Never>?
    private var isRefreshingSnapshot = false
    private var subscribedMarketSymbols = Set<String>()
    private let defaultMarketSymbols = ["BTCUSDT", "ETHUSDT", "SOLUSDT", "BNBUSDT"]
    private let automaticRefreshInterval: UInt64 = 10 * 1_000_000_000

    var totalUnrealizedPnL: Decimal {
        positions.reduce(Decimal.zero) { $0 + $1.unrealizedPnL }
    }

    func start() {
        startMarketStream()
        startAutomaticSnapshotRefresh()
        if ProcessInfo.processInfo.arguments.contains("--demo-one") {
            setScenario(.one)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--demo-eight") {
            setScenario(.eight)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            setScenario(.three)
            return
        }
        guard let credentials = KeychainService.shared.loadCredentials() else {
            positions = []
            connectionState = .notConfigured
            isUsingRealData = false
            lastUpdatedAt = nil
            return
        }
        currentCredentials = credentials

        Task { [weak self] in
            guard let self else { return }
            do {
                try await connect(credentials: credentials, persist: false, restartUserStream: true)
            } catch {
                handleConnectionFailure(error)
            }
        }
    }

    func stop() {
        snapshotDebounceTask?.cancel()
        snapshotDebounceTask = nil
        snapshotRefreshTask?.cancel()
        snapshotRefreshTask = nil
        userDataStream?.stop()
        userDataStream = nil
        marketStream.stop()
        subscribedMarketSymbols.removeAll()
        connectionState = .disconnected
    }

    func reloadSnapshot() {
        beginSnapshotRefresh(restartUserStream: false)
    }

    func resumeRealData() {
        beginSnapshotRefresh(restartUserStream: true)
    }

    func setScenario(_ scenario: MockScenario) {
        userDataStream?.stop()
        userDataStream = nil
        currentCredentials = nil
        subscribedMarketSymbols.removeAll()
        self.scenario = scenario
        positions = scenario.positions
        connectionState = .mock
        lastUpdatedAt = Date()
        isUsingRealData = false
        lastError = nil
    }

    func saveAndConnect(apiKey: String, apiSecret: String) async throws {
        let credentials = APICredentials(
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            apiSecret: apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !credentials.apiKey.isEmpty, !credentials.apiSecret.isEmpty else {
            throw BinanceRESTError.server(code: -1, message: "API Key 和 API Secret 不能为空")
        }
        try await connect(credentials: credentials, persist: true, restartUserStream: true)
    }

    func deleteCredentials() throws {
        try KeychainService.shared.deleteCredentials()
        userDataStream?.stop()
        userDataStream = nil
        currentCredentials = nil
        restClient = nil
        positions = []
        isUsingRealData = false
        lastError = nil
        connectionState = .notConfigured
        lastUpdatedAt = nil
    }

    private func connect(credentials: APICredentials, persist: Bool, restartUserStream: Bool) async throws {
        if connectionState != .live {
            connectionState = .connecting
        }
        do {
            var client = BinanceRESTClient(credentials: credentials)
            let snapshot = try await client.fetchPositions()
            if persist {
                try KeychainService.shared.save(credentials: credentials)
            }
            restClient = client
            currentCredentials = credentials
            positions = snapshot
            connectionState = .live
            isUsingRealData = true
            lastUpdatedAt = Date()
            lastError = nil
            updateMarketStreamSymbols()
            if restartUserStream {
                startUserDataStream(credentials: credentials)
            }
        } catch {
            handleConnectionFailure(error)
            throw error
        }
    }

    func applyMarkPrice(symbol: String, price: Decimal) {
        for index in positions.indices where positions[index].symbol == symbol {
            positions[index].markPrice = price
            let amount = abs(positions[index].positionAmount)
            let difference = positions[index].side == .long
                ? price - positions[index].entryPrice
                : positions[index].entryPrice - price
            positions[index].unrealizedPnL = difference * amount
            if let margin = positions[index].positionInitialMargin, margin > 0 {
                positions[index].roiPercent = positions[index].unrealizedPnL / margin * 100
            }
            positions[index].updatedAt = Date()
        }
        lastUpdatedAt = Date()
    }

    private func startMarketStream() {
        subscribedMarketSymbols = Set(defaultMarketSymbols)
        marketStream.start(
            symbols: defaultMarketSymbols,
            onQuote: { [weak self] quote in
                Task { @MainActor [weak self] in
                    self?.receive(quote: quote)
                }
            },
            onState: { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.marketStreamState = state
                }
            }
        )
    }

    private func updateMarketStreamSymbols() {
        let symbols = defaultMarketSymbols + positions.map(\.symbol)
        let symbolSet = Set(symbols)
        guard symbolSet != subscribedMarketSymbols else { return }
        subscribedMarketSymbols = symbolSet
        marketStream.start(
            symbols: symbols,
            onQuote: { [weak self] quote in
                Task { @MainActor [weak self] in
                    self?.receive(quote: quote)
                }
            },
            onState: { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.marketStreamState = state
                }
            }
        )
    }

    private func receive(quote: MarketQuote) {
        if let index = marketQuotes.firstIndex(where: { $0.symbol == quote.symbol }) {
            marketQuotes[index] = quote
        } else {
            marketQuotes.append(quote)
            marketQuotes.sort { $0.symbol < $1.symbol }
        }
        if isUsingRealData, let markPrice = quote.markPrice {
            applyMarkPrice(symbol: quote.symbol, price: markPrice)
        }
    }

    private func startUserDataStream(credentials: APICredentials) {
        userDataStream?.stop()
        let service = BinanceUserDataStreamService(apiKey: credentials.apiKey)
        userDataStream = service
        service.start { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleSnapshotReload()
            }
        }
    }

    private func scheduleSnapshotReload() {
        snapshotDebounceTask?.cancel()
        snapshotDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.reloadSnapshot()
        }
    }

    private func startAutomaticSnapshotRefresh() {
        snapshotRefreshTask?.cancel()
        snapshotRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self?.automaticRefreshInterval ?? 10 * 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard self.currentCredentials != nil else { continue }
                self.reloadSnapshot()
            }
        }
    }

    private func beginSnapshotRefresh(restartUserStream: Bool) {
        Task { [weak self] in
            guard let self else { return }
            await self.performSnapshotRefresh(restartUserStream: restartUserStream)
        }
    }

    private func performSnapshotRefresh(restartUserStream: Bool) async {
        guard !isRefreshingSnapshot else { return }
        isRefreshingSnapshot = true
        defer { isRefreshingSnapshot = false }

        // A refresh must never fall back to the Keychain. Credentials are
        // loaded once at startup (or when the user saves a new API) and kept
        // in memory for the lifetime of this connection.
        guard let credentials = currentCredentials else { return }

        do {
            try await connect(credentials: credentials, persist: false, restartUserStream: restartUserStream)
        } catch {
            handleConnectionFailure(error)
        }
    }

    private func handleConnectionFailure(_ error: Error) {
        connectionState = .authError(error.localizedDescription)
        lastError = error.localizedDescription
        isUsingRealData = false
    }
}

enum MockScenario: Int, CaseIterable {
    case zero = 0
    case one = 1
    case three = 3
    case eight = 8

    var title: String {
        "\(rawValue) 仓"
    }

    var positions: [PositionItem] {
        let base = MockScenario.allPositions
        switch self {
        case .zero: return []
        case .one: return Array(base.prefix(1))
        case .three: return Array(base.prefix(3))
        case .eight: return base
        }
    }

    private static var allPositions: [PositionItem] {
        let now = Date()
        return [
            make("ETHUSDT", .long, 2, 3.20, 2615.30, 2668.10, 128.52, 6.42, 2002.00, now),
            make("BTCUSDT", .short, 3, 0.015, 86468.20, 88613.50, -32.18, -1.21, 91200.00, now),
            make("SOLUSDT", .long, 5, 12.00, 188.40, 191.92, 42.28, 3.14, 144.00, now),
            make("BNBUSDT", .long, 2, 1.80, 608.20, 614.18, 10.76, 1.97, 546.00, now),
            make("XRPUSDT", .short, 4, 450.00, 2.1480, 2.1090, 17.55, 4.07, 431.00, now),
            make("DOGEUSDT", .long, 3, 1800.00, 0.23840, 0.24110, 4.86, 1.82, 267.00, now),
            make("ADAUSDT", .short, 2, 900.00, 0.8120, 0.8272, -13.68, -1.86, 736.00, now),
            make("LINKUSDT", .long, 3, 32.00, 18.42, 18.95, 16.96, 2.88, 588.00, now)
        ]
    }

    private static func make(
        _ symbol: String,
        _ side: PositionSide,
        _ leverage: Int,
        _ amount: Decimal,
        _ entry: Decimal,
        _ mark: Decimal,
        _ pnl: Decimal,
        _ roi: Decimal,
        _ liquidation: Decimal,
        _ now: Date
    ) -> PositionItem {
        PositionItem(
            id: "\(symbol)_\(side.rawValue.uppercased())",
            symbol: symbol,
            side: side,
            positionAmount: side == .long ? amount : -amount,
            leverage: leverage,
            entryPrice: entry,
            markPrice: mark,
            liquidationPrice: liquidation,
            unrealizedPnL: pnl,
            roiPercent: roi,
            marginType: .cross,
            positionInitialMargin: abs(pnl / roi * 100),
            updatedAt: now
        )
    }
}
