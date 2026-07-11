import Foundation
import Security

enum LicenseActivationStoreError: LocalizedError {
    case invalidStoredData
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidStoredData:
            "Stored activation data could not be read."
        case let .keychainStatus(status):
            "Keychain error \(status)."
        }
    }
}

final class LicenseActivationStore {
    private let service = "\(AppIdentity.bundleIdentifier).license"
    private let legacyProductionServices = ["dev.assist.app.license"]
    private let account = "activation"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> LicenseActivation? {
        if let activation = try load(service: service) {
            return activation
        }

        guard !AppIdentity.isDevelopmentBundle else {
            return nil
        }

        for legacyService in legacyProductionServices {
            if let activation = try load(service: legacyService) {
                try? save(activation)
                return activation
            }
        }

        return nil
    }

    private func load(service: String) throws -> LicenseActivation? {
        var query = baseQuery(service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw LicenseActivationStoreError.keychainStatus(status)
        }

        guard let data = item as? Data else {
            throw LicenseActivationStoreError.invalidStoredData
        }

        return try decoder.decode(LicenseActivation.self, from: data)
    }

    func save(_ activation: LicenseActivation) throws {
        let data = try encoder.encode(activation)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(service: service) as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var query = baseQuery(service: service)
            query[kSecValueData as String] = data
            let addStatus = SecItemAdd(query as CFDictionary, nil)

            guard addStatus == errSecSuccess else {
                throw LicenseActivationStoreError.keychainStatus(addStatus)
            }

            return
        }

        throw LicenseActivationStoreError.keychainStatus(updateStatus)
    }

    func clear() {
        SecItemDelete(baseQuery(service: service) as CFDictionary)
        guard !AppIdentity.isDevelopmentBundle else { return }

        for legacyService in legacyProductionServices {
            SecItemDelete(baseQuery(service: legacyService) as CFDictionary)
        }
    }

    private func baseQuery(service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
