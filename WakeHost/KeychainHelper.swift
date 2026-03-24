import Foundation
import Security

/// A simple helper for storing/retrieving strings in the keychain.
struct KeychainHelper {
    private static let service = "com.dohnesorge.WakeHost"
    private static let migrationDefaultsKey = "keychainMigrated"
    private static let credentialKeys = ["opn_key", "opn_secret"]
    private static let accessGroupEntitlement = "keychain-access-groups" as CFString
    private static let applicationIdentifierEntitlement = "application-identifier" as CFString
    private static let itemAccessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    private static let accessGroup: String? = {
        guard let task = SecTaskCreateFromSelf(nil) else { return nil }

        if let groups = SecTaskCopyValueForEntitlement(task, accessGroupEntitlement, nil) as? [String],
           let group = groups.first(where: { $0.hasSuffix(service) }) ?? groups.first {
            return group
        }

        if let applicationIdentifier = SecTaskCopyValueForEntitlement(task, applicationIdentifierEntitlement, nil) as? String,
           let separatorIndex = applicationIdentifier.firstIndex(of: ".") {
            let prefix = applicationIdentifier[..<separatorIndex]
            return "\(prefix).\(service)"
        }

        return nil
    }()

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

    static func migrateLegacyItemsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationDefaultsKey) else { return }
        guard accessGroup != nil else { return }

        for key in credentialKeys {
            guard get(key) == nil, let legacyValue = getLegacy(key) else { continue }
            set(legacyValue, forKey: key)
            deleteLegacy(key)
        }

        UserDefaults.standard.set(true, forKey: migrationDefaultsKey)
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

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

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
            kSecAttrService as String: service,
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
