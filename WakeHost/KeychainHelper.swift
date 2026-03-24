import Foundation
import Security

/// A simple helper for storing/retrieving strings in the keychain.
struct KeychainHelper {
    private static let service = "com.dohnesorge.WakeHost"

    static func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        SecItemDelete(query(for: key) as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query = query(for: key, returningData: true)
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }

    static func delete(_ key: String) {
        SecItemDelete(query(for: key) as CFDictionary)
    }

    private static func query(
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
}
