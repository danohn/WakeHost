import Foundation
import Security

/// A simple helper for storing/retrieving strings in the keychain.
struct KeychainHelper {
    private static let service = "com.dohnesorge.WakeHost"

    static func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        SecItemDelete(scopedQuery(for: key) as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query = scopedQuery(for: key, returningData: true)
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }

        if let legacyValue = getLegacy(key) {
            set(legacyValue, forKey: key)
            deleteLegacy(key)
            return legacyValue
        }

        return nil
    }

    static func delete(_ key: String) {
        SecItemDelete(scopedQuery(for: key) as CFDictionary)
        deleteLegacy(key)
    }

    private static func scopedQuery(
        for key: String,
        returningData: Bool = false
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }

        return query
    }

    private static func legacyQuery(
        for key: String,
        returningData: Bool = false
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }

        return query
    }

    private static func getLegacy(_ key: String) -> String? {
        let query = legacyQuery(for: key, returningData: true)
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }

    private static func deleteLegacy(_ key: String) {
        SecItemDelete(legacyQuery(for: key) as CFDictionary)
    }
}
