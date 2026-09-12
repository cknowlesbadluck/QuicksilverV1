import Foundation
import SwiftData
import Core

/// SwiftData-backed implementation of MemoryStore.
/// Replaceable storage backend. Privacy-first, on-device only.
@available(iOS 17.0, macOS 14.0, *)
public actor SwiftDataMemoryStore: MemoryStore {

    private let container: ModelContainer
    private let context: ModelContext

    public init(inMemory: Bool = false) throws {
        let schema = Schema([MemoryEntry.self])
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
        self.context.autosaveEnabled = true
    }

    public func loadAll() async throws -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryEntry>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let entries = try context.fetch(descriptor)
        return entries.map { $0.toMemoryItem() }
    }

    public func save(_ item: MemoryItem) async throws {
        // Hoist id: #Predicate cannot lower member access on a captured struct.
        let itemID = item.id
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.id == itemID }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: item)
        } else {
            context.insert(MemoryEntry(from: item))
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        for entry in try context.fetch(descriptor) {
            context.delete(entry)
        }
        try context.save()
    }

    /// Batch deletion in a single fetch and context save, eliminating N+1 database operations.
    public func delete(ids: Set<UUID>) async throws {
        guard !ids.isEmpty else { return }
        let targetIDs = ids
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { targetIDs.contains($0.id) }
        )
        for entry in try context.fetch(descriptor) {
            context.delete(entry)
        }
        try context.save()
    }

    public func deleteAll(in category: MemoryItem.Category) async throws {
        let categoryRaw = category.rawValue
        let descriptor = FetchDescriptor<MemoryEntry>(
            predicate: #Predicate { $0.categoryRaw == categoryRaw }
        )
        for entry in try context.fetch(descriptor) {
            context.delete(entry)
        }
        try context.save()
    }
}

// MARK: - SwiftData model (internal to Memory module)

@available(iOS 17.0, macOS 14.0, *)
@Model
final class MemoryEntry {
    @Attribute(.unique) var id: UUID
    var key: String
    var categoryRaw: String
    var value: String
    var createdAt: Date
    var updatedAt: Date
    var metadataData: Data?
    var importance: Double
    var personaScope: String?

    init(from item: MemoryItem) {
        self.id = item.id
        self.key = item.key
        self.categoryRaw = item.category.rawValue
        self.value = item.value
        self.createdAt = item.createdAt
        self.updatedAt = item.updatedAt
        self.metadataData = try? JSONEncoder().encode(item.metadata)
        self.importance = item.importance
        self.personaScope = item.personaScope
    }

    func update(from item: MemoryItem) {
        self.key = item.key
        self.categoryRaw = item.category.rawValue
        self.value = item.value
        self.updatedAt = item.updatedAt
        self.metadataData = try? JSONEncoder().encode(item.metadata)
        self.importance = item.importance
        self.personaScope = item.personaScope
    }

    func toMemoryItem() -> MemoryItem {
        let metadata: [String: String]
        if let data = metadataData,
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            metadata = decoded
        } else {
            metadata = [:]
        }
        let category = MemoryItem.Category(rawValue: categoryRaw) ?? .temporary
        return MemoryItem(
            id: id,
            key: key,
            category: category,
            value: value,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            importance: importance,
            personaScope: personaScope
        )
    }
}
