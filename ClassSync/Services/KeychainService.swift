import Foundation
import Security

enum KeychainError: LocalizedError, Equatable {
    case emptyToken
    case unexpectedData
    case status(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyToken:
            "The token was empty and was not saved."
        case .unexpectedData:
            "Keychain returned an unexpected value."
        case let .status(status):
            SecCopyErrorMessageString(status, nil) as String? ?? "Keychain operation failed (\(status))."
        }
    }
}

protocol KeychainClient {
    func add(_ query: CFDictionary) -> OSStatus
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}

struct SystemKeychainClient: KeychainClient {
    func add(_ query: CFDictionary) -> OSStatus {
        SecItemAdd(query, nil)
    }

    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        SecItemCopyMatching(query, result)
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        SecItemDelete(query)
    }
}

struct KeychainService {
    private let service: String
    private let client: any KeychainClient

    init(
        service: String = Bundle.main.bundleIdentifier ?? "com.annasamar.ClassSync",
        client: any KeychainClient = SystemKeychainClient()
    ) {
        self.service = service
        self.client = client
    }

    func saveToken(_ token: Data, account: String) throws {
        guard !token.isEmpty else { throw KeychainError.emptyToken }
        try deleteToken(account: account)

        var query = baseQuery(account: account)
        query[kSecValueData as String] = token
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = client.add(query as CFDictionary)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    func readToken(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = client.copyMatching(query as CFDictionary, result: &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        guard let data = result as? Data else { throw KeychainError.unexpectedData }
        return data
    }

    func deleteToken(account: String) throws {
        let status = client.delete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

