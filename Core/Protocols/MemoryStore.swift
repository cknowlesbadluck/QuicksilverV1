import Foundation

/// Contract for persistent memory storage.
/// Implementations live in the Memory module (UserDefaults, SwiftData, etc.).
public protocol MemoryStore: Sendable {
    func loadAll() async throws -> [MemoryItem]
    func save(_ item: MemoryItem) async throws
    func delete(id: UUID) async throws
    func delete(ids: Set<UUID>) async throws
    func deleteAll(in category: MemoryItem.Category) async throws
}

extension MemoryStore {
    /// Default implementation for batch deletion that falls back to sequential single deletes.
    /// Specific implementations should override this to execute a single batch persistence call.
    public func delete(ids: Set<UUID>) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
}
