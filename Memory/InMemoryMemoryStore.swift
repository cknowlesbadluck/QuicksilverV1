import Foundation
import Core

/// Deterministic in-memory store for unit tests.
public actor InMemoryMemoryStore: MemoryStore {
    private var items: [MemoryItem] = []

    public init() {}

    public func loadAll() async throws -> [MemoryItem] {
        items
    }

    public func save(_ item: MemoryItem) async throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    public func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    /// Batch deletion in a single O(N) pass over memory items instead of O(N * K).
    public func delete(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
    }

    public func deleteAll(in category: MemoryItem.Category) async throws {
        items.removeAll { $0.category == category }
    }
}
