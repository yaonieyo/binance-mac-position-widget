import Foundation

final class BinanceMarketStreamService {
    private var task: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var running = false

    func start(
        symbols: [String],
        onQuote: @escaping @Sendable (MarketQuote) -> Void,
        onState: @escaping @Sendable (MarketStreamState) -> Void
    ) {
        stop()
        let normalized = Array(Set(symbols.map { $0.uppercased() })).sorted()
        guard !normalized.isEmpty else {
            onState(.disconnected)
            return
        }

        running = true
        task = Task { [weak self] in
            await self?.run(symbols: normalized, onQuote: onQuote, onState: onState)
        }
    }

    func stop() {
        running = false
        task?.cancel()
        task = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    deinit {
        stop()
    }

    private func run(
        symbols: [String],
        onQuote: @escaping @Sendable (MarketQuote) -> Void,
        onState: @escaping @Sendable (MarketStreamState) -> Void
    ) async {
        let streams = symbols.flatMap { symbol in
            let lower = symbol.lowercased()
            return ["\(lower)@markPrice@1s", "\(lower)@ticker"]
        }.joined(separator: "/")

        guard let url = URL(string: "wss://fstream.binance.com/market/stream?streams=\(streams)") else {
            onState(.disconnected)
            return
        }

        var delay: UInt64 = 1
        var quotes: [String: MarketQuote] = [:]

        while running && !Task.isCancelled {
            do {
                onState(delay == 1 ? .connecting : .reconnecting)
                let webSocket = URLSession.shared.webSocketTask(with: url)
                socket = webSocket
                webSocket.resume()
                onState(.live)
                delay = 1

                while running && !Task.isCancelled {
                    let message = try await webSocket.receive()
                    let data: Data
                    switch message {
                    case .data(let value): data = value
                    case .string(let value): data = Data(value.utf8)
                    @unknown default: continue
                    }
                    guard let quote = Self.parse(data: data, existing: &quotes) else { continue }
                    onQuote(quote)
                }

                webSocket.cancel(with: .normalClosure, reason: nil)
            } catch {
                if !running || Task.isCancelled { break }
                onState(.reconnecting)
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                delay = min(delay * 2, 30)
            }
        }

        onState(.disconnected)
    }

    private static func parse(data: Data, existing: inout [String: MarketQuote]) -> MarketQuote? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = root["data"] as? [String: Any],
            let event = payload["e"] as? String,
            let symbol = payload["s"] as? String,
            let eventTime = payload["E"] as? NSNumber
        else { return nil }

        var quote = existing[symbol] ?? MarketQuote(
            symbol: symbol,
            lastPrice: nil,
            markPrice: nil,
            changePercent: nil,
            updatedAt: Date()
        )
        quote.updatedAt = Date(timeIntervalSince1970: eventTime.doubleValue / 1000)

        switch event {
        case "markPriceUpdate":
            guard let raw = payload["p"] as? String, let price = Decimal(string: raw) else { return nil }
            quote.markPrice = price
        case "24hrTicker":
            if let raw = payload["c"] as? String { quote.lastPrice = Decimal(string: raw) }
            if let raw = payload["P"] as? String { quote.changePercent = Decimal(string: raw) }
        default:
            return nil
        }

        existing[symbol] = quote
        return quote
    }
}
