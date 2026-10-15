import Foundation
import Security

struct APICredentials {
    let apiKey: String
    let apiSecret: String
}

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain 操作失败（\(status)）"
        case .invalidData:
            return "Keychain 凭证格式无效"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "local.binance.position.widget.credentials"
    private let apiKeyAccount = "apiKey"
    private let apiSecretAccount = "apiSecret"

    func save(credentials: APICredentials) throws {
        try save(value: credentials.apiKey, account: apiKeyAccount)
        try save(value: credentials.apiSecret, account: apiSecretAccount)
    }

    func loadCredentials() -> APICredentials? {
        guard let apiKey = load(account: apiKeyAccount),
              let apiSecret = load(account: apiSecretAccount),
              !apiKey.isEmpty,
              !apiSecret.isEmpty else {
            return nil
        }
        return APICredentials(apiKey: apiKey, apiSecret: apiSecret)
    }

    var hasCredentials: Bool {
        guard let apiKey = load(account: apiKeyAccount),
              let apiSecret = load(account: apiSecretAccount) else {
            return false
        }
        return !apiKey.isEmpty && !apiSecret.isEmpty
    }

    var maskedAPIKey: String? {
        guard let apiKey = load(account: apiKeyAccount), !apiKey.isEmpty else { return nil }
        return "•••• (apiKey.suffix(4))"
    }

    func deleteCredentials() throws {
        for account in [apiKeyAccount, apiSecretAccount] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.unexpectedStatus(status)
            }
        }
    }

    private func save(value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
