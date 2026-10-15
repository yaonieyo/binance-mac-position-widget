import CryptoKit
import Foundation

enum BinanceSigner {
    static func queryString(_ parameters: [(String, String)]) -> String {
        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.percentEncodedQuery ?? ""
    }

    static func signature(secret: String, query: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let digest = HMAC<SHA256>.authenticationCode(for: Data(query.utf8), using: key)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
