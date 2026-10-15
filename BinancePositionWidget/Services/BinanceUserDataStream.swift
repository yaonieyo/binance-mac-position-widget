import Foundation

final class BinanceUserDataStreamService {
    private let apiKey: String
    private let baseURL = URL(string: "https://fapi.binance.com")!
    private let webSocketBaseURL = "wss://fstream.binance.com/private/ws/"
    private var task: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var running = false

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func start(onAccountUpdate: @escaping @Sendable () -> Void) {
        stop()
        running = true
        task = Task { [weak self] in
            await self?.run(onAccountUpdate: onAccountUpdate)
        }
    }

    func stop() {
        running = false
        task?.cancel()
        keepAliveTask?.cancel()
        task = nil
        keepAliveTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    deinit {
        stop()
    }

    private func run(onAccountUpdate: @escaping @Sendable () -> Void) async {
        var delay: UInt64 = 1

        while running && !Task.isCancelled {
            do {
                let listenKey = try await createListenKey()
                guard let url = URL(string: webSocketBaseURL + listenKey) else { throw StreamError.invalidURL }
                let webSocket = URLSession.shared.webSocketTask(with: url)
                socket = webSocket
                webSocket.resume()
                delay = 1

                keepAliveTask?.cancel()
                keepAliveTask = Task { [weak self] in
                    while let self, self.running && !Task.isCancelled {
                        do {
                            try await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                            try await self.keepAlive(listenKey: listenKey)
                        } catch {
                            break
                        }
                    }
                }

                while running && !Task.isCancelled {
                    let message = try await webSocket.receive()
                    let data: Data
                    switch message {
                    case .data(let value): data = value
                    case .string(let value): data = Data(value.utf8)
                    @unknown default: continue
                    }
                    guard
                        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let event = object["e"] as? String
                    else { continue }

                    if ["ACCOUNT_UPDATE", "ORDER_TRADE_UPDATE", "ACCOUNT_CONFIG_UPDATE", "listenKeyExpired"].contains(event) {
                        onAccountUpdate()
                    }
                    if event == "listenKeyExpired" { break }
                }

                keepAliveTask?.cancel()
                webSocket.cancel(with: .normalClosure, reason: nil)
            } catch {
                if !running || Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                delay = min(delay * 2, 30)
            }
        }
    }

    private func createListenKey() async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("/fapi/v1/listenKey"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue(apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ListenKeyDTO.self, from: data).listenKey
    }

    private func keepAlive(listenKey: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("/fapi/v1/listenKey"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "listenKey", value: listenKey)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        request.timeoutInterval = 10
        request.setValue(apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(BinanceErrorDTO.self, from: data) {
                throw StreamError.server(code: error.code, message: error.msg)
            }
            throw StreamError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

private struct ListenKeyDTO: Decodable {
    let listenKey: String
}

private struct BinanceErrorDTO: Decodable {
    let code: Int
    let msg: String
}

private enum StreamError: LocalizedError {
    case invalidURL
    case server(code: Int, message: String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Binance WebSocket 地址无效"
        case .server(let code, let message): return "Binance 流错误 \(code)：\(message)"
        case .httpStatus(let status): return "Binance 流 HTTP 错误：\(status)"
        }
    }
}
