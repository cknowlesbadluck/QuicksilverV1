import Foundation
import Security

/// Device-only Keychain storage for credentials and sensitive local memory.
/// Values are never written to UserDefaults or logged.
public enum KeychainStore: Sendable {
    private static let service = "com.quicksilver.keychain"

    public static func data(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return data
    }

    /// Stores `data` for `key`, or removes the item when `data` is nil.
    ///
    /// Updates in place with `SecItemUpdate` and only adds when the item does not exist
    /// yet. The previous delete-then-add left a window in which a failed add (or a crash)
    /// lost the existing credential.
    @discardableResult
    public static func set(_ data: Data?, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        guard let data else {
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = query
        addQuery.merge(attributes) { _, new in new }
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    public static func string(forKey key: String) -> String? {
        guard let data = data(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func set(_ value: String?, forKey key: String) -> Bool {
        set(value?.data(using: .utf8), forKey: key)
    }

    public static func delete(forKey key: String) {
        _ = set(nil as Data?, forKey: key)
    }
}
