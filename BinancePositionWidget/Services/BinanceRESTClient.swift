import Foundation

struct BinanceRESTClient {
    private let apiKey: String
    private let apiSecret: String
    private let baseURL = URL(string: "https://fapi.binance.com")!
    private var timeOffsetMilliseconds: Int64 = 0

    init(credentials: APICredentials) {
        self.apiKey = credentials.apiKey
        self.apiSecret = credentials.apiSecret
    }

    mutating func fetchPositions() async throws -> [PositionItem] {
        try await syncServerTime()
        let account: BinanceAccountDTO = try await signedRequest(path: "/fapi/v3/account")
        let risk: [BinancePositionRiskDTO] = try await signedRequest(path: "/fapi/v3/positionRisk")

        let configs: [BinanceSymbolConfigDTO] = try await signedRequest(path: "/fapi/v1/symbolConfig")
        let configBySymbol = Dictionary(uniqueKeysWithValues: configs.map { ($0.symbol, $0) })
        _ = account.positions

        return try risk.compactMap { item in
            guard let amount = Decimal(string: item.positionAmt), amount != 0,
                  let entryPrice = Decimal(string: item.entryPrice),
                  let markPrice = Decimal(string: item.markPrice),
                  let pnl = Decimal(string: item.unRealizedProfit ?? item.unrealizedProfit ?? "0") else {
                return nil
            }

            guard let config = configBySymbol[item.symbol] else {
                throw BinanceRESTError.invalidData("缺少 \(item.symbol) 的账户配置")
            }

            let side: PositionSide
            switch item.positionSide.uppercased() {
            case "SHORT": side = .short
            case "LONG": side = .long
            default: side = amount >= 0 ? .long : .short
            }

            let initialMargin = (item.positionInitialMargin ?? item.initialMargin)
                .flatMap { Decimal(string: $0) }
                .flatMap { $0 > 0 ? $0 : nil }
            let roi = initialMargin.map { $0 > 0 ? pnl / $0 * 100 : nil } ?? nil
            let liquidation = item.liquidationPrice.flatMap { Decimal(string: $0) }.flatMap { $0 > 0 ? $0 : nil }
            let marginType = Self.marginType(from: config.marginType)
            let timestamp = Date(timeIntervalSince1970: TimeInterval(item.updateTime ?? 0) / 1000)

            return PositionItem(
                id: "\(item.symbol)_\(item.positionSide)",
                symbol: item.symbol,
                side: side,
                positionAmount: amount,
                leverage: config.leverage,
                entryPrice: entryPrice,
                markPrice: markPrice,
                liquidationPrice: liquidation,
                unrealizedPnL: pnl,
                roiPercent: roi,
                marginType: marginType,
                positionInitialMargin: initialMargin,
                updatedAt: timestamp
            )
        }
    }

    private mutating func syncServerTime() async throws {
        let request = URLRequest(url: baseURL.appendingPathComponent("/fapi/v1/time"))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        guard let server = try? JSONDecoder().decode(BinanceTimeDTO.self, from: data) else {
            throw BinanceRESTError.invalidData("Server Time 返回格式无效")
        }
        timeOffsetMilliseconds = server.serverTime - Int64(Date().timeIntervalSince1970 * 1000)
    }

    private mutating func signedRequest<T: Decodable>(path: String) async throws -> T {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000) + timeOffsetMilliseconds
        let query = BinanceSigner.queryString([
            ("recvWindow", "5000"),
            ("timestamp", String(timestamp))
        ])
        let signedQuery = "\(query)&signature=\(BinanceSigner.signature(secret: apiSecret, query: query))"
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = signedQuery
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        do {
            if let error = try? JSONDecoder().decode(BinanceErrorDTO.self, from: data), error.code < 0 {
                throw BinanceRESTError.server(code: error.code, message: error.msg)
            }
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as BinanceRESTError {
            throw error
        } catch {
            throw BinanceRESTError.decoding(path: path, detail: error.localizedDescription)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(BinanceErrorDTO.self, from: data) {
                throw BinanceRESTError.server(code: error.code, message: error.msg)
            }
            throw BinanceRESTError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    private static func marginType(from raw: String) -> MarginType? {
        switch raw.uppercased() {
        case "CROSSED", "CROSS": return .cross
        case "ISOLATED": return .isolated
        default: return nil
        }
    }
}

enum BinanceRESTError: LocalizedError {
    case server(code: Int, message: String)
    case httpStatus(Int)
    case invalidData(String)
    case decoding(path: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .server(let code, let message): return "Binance 错误 \(code)：\(message)"
        case .httpStatus(let status): return "Binance HTTP 错误：\(status)"
        case .invalidData(let message): return "Binance 数据无效：\(message)"
        case .decoding(let path, let detail): return "Binance \(path) 数据解析失败：\(detail)"
        }
    }

}

private struct BinanceTimeDTO: Decodable {
    let serverTime: Int64
}

private struct BinanceErrorDTO: Decodable {
    let code: Int
    let msg: String
}

private struct BinanceAccountDTO: Decodable {
    let positions: [BinanceAccountPositionDTO]
}

private struct BinanceAccountPositionDTO: Decodable {
    let symbol: String?
    let positionSide: String?
    let initialMargin: String?
}

private struct BinancePositionRiskDTO: Decodable {
    let symbol: String
    let positionAmt: String
    let entryPrice: String
    let markPrice: String
    let liquidationPrice: String?
    let positionSide: String
    let unRealizedProfit: String?
    let unrealizedProfit: String?
    let initialMargin: String?
    let positionInitialMargin: String?
    let updateTime: Int64?
}

private struct BinanceSymbolConfigDTO: Decodable {
    let symbol: String
    let marginType: String
    let leverage: Int
}
