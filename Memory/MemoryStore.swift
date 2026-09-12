import Foundation
import Core

// MemoryStore protocol now lives in Core/Protocols/MemoryStore.swift.
// This file provides the UserDefaults-backed implementation.

public actor UserDefaultsMemoryStore: MemoryStore {
    private let defaults: UserDefaults
    private let storageKey = "quicksilver.memory.items"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadAll() async throws -> [MemoryItem] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return try JSONDecoder().decode([MemoryItem].self, from: data)
    }

    public func save(_ item: MemoryItem) async throws {
        var items = try await loadAll()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        let data = try JSONEncoder().encode(items)
        defaults.set(data, forKey: storageKey)
    }

    public func delete(id: UUID) async throws {
        var items = try await loadAll()
        items.removeAll { $0.id == id }
        let data = try JSONEncoder().encode(items)
        defaults.set(data, forKey: storageKey)
    }

    /// Batch deletion in a single read/encode/write cycle, avoiding N+1 disk write operations.
    public func delete(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        var items = try await loadAll()
        items.removeAll { ids.contains($0.id) }
        let data = try JSONEncoder().encode(items)
        defaults.set(data, forKey: storageKey)
    }

    public func deleteAll(in category: MemoryItem.Category) async throws {
        var items = try await loadAll()
        items.removeAll { $0.category == category }
        let data = try JSONEncoder().encode(items)
        defaults.set(data, forKey: storageKey)
    }
}
