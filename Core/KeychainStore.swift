import Foundation
import Security

/// Device-only Keychain storage for credentials and sensitive local memory.
/// Values are never written to UserDefaults or logged.
public enum KeychainStore: Sendable {
    private static let service = "com.quicksilver.keychain"

    /// Typed read failure. A missing item is *not* an error (`readData` returns nil).
    public enum ReadError: Error, Equatable, Sendable {
        /// Device locked / data protection unavailable (`errSecInteractionNotAllowed`).
        case locked
        /// Any other Keychain status.
        case failed(OSStatus)
    }

    /// What a credential read tells the UI: present, absent, or unreadable because the
    /// device hasn't been unlocked since boot (items are `AfterFirstUnlockThisDeviceOnly`).
    public enum CredentialState: Equatable, Sendable {
        case present
        case missing
        case locked
        case unreadable(OSStatus)
    }

    public static func credentialState(forKey key: String) -> CredentialState {
        credentialState(from: Result { () throws(ReadError) -> Data? in try readData(forKey: key) })
    }

    static func credentialState(from result: Result<Data?, ReadError>) -> CredentialState {
        switch result {
        case .success(let data?): return data.isEmpty ? .missing : .present
        case .success(nil): return .missing
        case .failure(.locked): return .locked
        case .failure(.failed(let status)): return .unreadable(status)
        }
    }

    /// Maps a `SecItemCopyMatching` status: success → data, not found → nil, otherwise typed error.
    static func interpret(status: OSStatus, item: CFTypeRef?) throws(ReadError) -> Data? {
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw .failed(errSecDecode) }
            return data
        case errSecItemNotFound:
            return nil
        case errSecInteractionNotAllowed:
            throw .locked
        default:
            throw .failed(status)
        }
    }

    /// Like `data(forKey:)` but distinguishes "absent" (nil) from "unreadable" (throws).
    public static func readData(forKey key: String) throws(ReadError) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return try interpret(status: status, item: item)
    }

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
