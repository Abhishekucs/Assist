import Foundation
import Security

enum KeychainSecretStoreError: LocalizedError {
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .keychainStatus(status):
            "Keychain error \(status)."
        }
    }
}

/// Generic passwords in the login Keychain, one per account name, under a
/// single service. Used for the Revenue module's API keys, which are never
/// written to preferences or logs.
struct KeychainSecretStore: Sendable {
    let service: String

    func secret(for account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func hasSecret(for account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func setSecret(_ secret: String, for account: String) throws {
        let data = Data(secret.utf8)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainSecretStoreError.keychainStatus(updateStatus)
        }

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainSecretStoreError.keychainStatus(addStatus)
        }
    }

    func removeSecret(for account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
