import Foundation
import Core

/// Secure fallback memory store for environments where SwiftData is unavailable.
/// Legacy UserDefaults data is migrated once into the device-only Keychain.
public actor KeychainMemoryStore: MemoryStore {
    private let storageKey: String
    private let legacyDefaults: UserDefaults?

    public init(
        storageKey: String = "quicksilver.memory.items",
        legacyDefaults: UserDefaults? = .standard
    ) {
        self.storageKey = storageKey
        self.legacyDefaults = legacyDefaults
    }

    public init(defaults: UserDefaults) {
        self.init(storageKey: "quicksilver.memory.items", legacyDefaults: defaults)
    }

    public func loadAll() async throws -> [MemoryItem] {
        if let data = KeychainStore.data(forKey: storageKey) {
            guard let items = try? JSONDecoder().decode([MemoryItem].self, from: data) else {
                throw AppError.configurationMissing("Stored memory is unreadable")
            }
            return items
        }

        guard let legacyDefaults,
              let legacyData = legacyDefaults.data(forKey: storageKey) else {
            return []
        }

        guard let items = try? JSONDecoder().decode([MemoryItem].self, from: legacyData) else {
            // Do not destroy data that cannot be decoded.
            throw AppError.configurationMissing("Legacy memory is unreadable")
        }

        let encoded = try JSONEncoder().encode(items)
        guard KeychainStore.set(encoded, forKey: storageKey) else {
            throw AppError.configurationMissing("Unable to migrate memory to secure storage")
        }

        legacyDefaults.removeObject(forKey: storageKey)
        return items
    }

    public func save(_ item: MemoryItem) async throws {
        var items = try await loadAll()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        let data = try JSONEncoder().encode(items)
        guard KeychainStore.set(data, forKey: storageKey) else {
            throw AppError.configurationMissing("Unable to persist memory securely")
        }
    }

    public func delete(id: UUID) async throws {
        var items = try await loadAll()
        items.removeAll { $0.id == id }
        let data = try JSONEncoder().encode(items)
        guard KeychainStore.set(data, forKey: storageKey) else {
            throw AppError.configurationMissing("Unable to persist memory securely")
        }
    }

    public func deleteAll(in category: MemoryItem.Category) async throws {
        var items = try await loadAll()
        items.removeAll { $0.category == category }
        let data = try JSONEncoder().encode(items)
        guard KeychainStore.set(data, forKey: storageKey) else {
            throw AppError.configurationMissing("Unable to persist memory securely")
        }
    }
}

/// Compatibility name retained temporarily for existing tests/integrations.
/// It is no longer backed by UserDefaults.
public typealias UserDefaultsMemoryStore = KeychainMemoryStore
