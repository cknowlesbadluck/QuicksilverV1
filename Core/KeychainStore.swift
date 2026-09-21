import Foundation
import Security

/// Minimal Keychain helper for storing sensitive data and configuration (API keys, user memory).
/// Privacy-first: values never leave the device, never logged, never written to UserDefaults.
///
/// Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// — Available after first device unlock, not backed up, device-only.
/// Suitable for keys and memory items that the app needs shortly after launch
/// while remaining unavailable when the device is locked.
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
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return data
    }

    @discardableResult
    public static func set(_ data: Data?, forKey key: String) -> Bool {
        // Delete first so we can replace
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let data else {
            return true // deletion is success when clearing
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    public static func string(forKey key: String) -> String? {
        guard let data = data(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func set(_ value: String?, forKey key: String) -> Bool {
        let data = value?.data(using: .utf8)
        return set(data, forKey: key)
    }

    public static func delete(forKey key: String) {
        set(nil as Data?, forKey: key)
    }
}
