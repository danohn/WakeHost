import Foundation
import Security

/// A simple helper for storing/retrieving strings in the keychain.
struct KeychainHelper {
    private static let service = "com.dohnesorge.WakeHost"
    private static let useDataProtectionKeychain = true
    private static let itemAccessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    static func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        SecItemDelete(scopedQuery(for: key) as CFDictionary)

        var attributes = scopedQuery(for: key)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = itemAccessibility

        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query = scopedQuery(for: key, returningData: true)
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }

    static func delete(_ key: String) {
        SecItemDelete(scopedQuery(for: key) as CFDictionary)
    }

    private static func scopedQuery(
        for key: String,
        returningData: Bool = false
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: useDataProtectionKeychain
        ]

        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }

        return query
    }
}
