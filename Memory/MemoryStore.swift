import Foundation
import Core

// MemoryStore protocol lives in Core/Protocols/MemoryStore.swift.
// This file provides the Keychain-backed secure storage implementation.

public actor KeychainMemoryStore: MemoryStore {
    private let storageKey: String
    private let legacyDefaults: UserDefaults?

    public init(storageKey: String = "quicksilver.memory.items", legacyDefaults: UserDefaults? = .standard) {
        self.storageKey = storageKey
        self.legacyDefaults = legacyDefaults
    }

    public init(defaults: UserDefaults) {
        self.init(storageKey: "quicksilver.memory.items", legacyDefaults: defaults)
    }

    public func loadAll() async throws -> [MemoryItem] {
        if let data = KeychainStore.data(forKey: storageKey) {
            return (try? JSONDecoder().decode([MemoryItem].self, from: data)) ?? []
        }

        if let legacyDefaults, let legacyData = legacyDefaults.data(forKey: storageKey) {
            if let items = try? JSONDecoder().decode([MemoryItem].self, from: legacyData) {
                if let encoded = try? JSONEncoder().encode(items) {
                    KeychainStore.set(encoded, forKey: storageKey)
                }
                legacyDefaults.removeObject(forKey: storageKey)
                return items
            }
        }

        return []
    }

    public func save(_ item: MemoryItem) async throws {
        var items = try await loadAll()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        let data = try JSONEncoder().encode(items)
        KeychainStore.set(data, forKey: storageKey)
    }

    public func delete(id: UUID) async throws {
        var items = try await loadAll()
        items.removeAll { $0.id == id }
        let data = try JSONEncoder().encode(items)
        KeychainStore.set(data, forKey: storageKey)
    }

    public func deleteAll(in category: MemoryItem.Category) async throws {
        var items = try await loadAll()
        items.removeAll { $0.category == category }
        let data = try JSONEncoder().encode(items)
        KeychainStore.set(data, forKey: storageKey)
    }
}

public typealias UserDefaultsMemoryStore = KeychainMemoryStore
