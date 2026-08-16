import Foundation
import Observation
import Core

@MainActor
@Observable
public final class MemoryManager {
    public private(set) var items: [MemoryItem] = []

    private let store: MemoryStore
    private let eventBus: EventBus
    private let logger: LoggerService

    public init(store: MemoryStore, eventBus: EventBus, logger: LoggerService) {
        self.store = store
        self.eventBus = eventBus
        self.logger = logger
    }

    public func load() async {
        do {
            items = try await store.loadAll()
            logger.info("Loaded \(items.count) memory items", category: logger.memory)
        } catch {
            logger.error("Failed to load memory: \(error.localizedDescription)", category: logger.memory)
        }
    }

    public func set(key: String, value: String, category: MemoryItem.Category, metadata: [String: String] = [:], importanceBoost: Double? = nil, personaScope: String? = nil) async {
        if let existing = items.first(where: { $0.key == key && $0.category == category }) {
            var updated = existing
            updated.value = value
            updated.updatedAt = Date()
            updated.metadata = metadata
            updated.importance = MemoryScorer.score(category: category, value: value, explicitBoost: importanceBoost, existing: existing.importance)
            if let personaScope { updated.personaScope = personaScope }
            await persist(updated)
        } else {
            let importance = MemoryScorer.score(category: category, value: value, explicitBoost: importanceBoost)
            let item = MemoryItem(key: key, category: category, value: value, metadata: metadata, importance: importance, personaScope: personaScope)
            await persist(item)
        }
    }

    public func value(for key: String, category: MemoryItem.Category) -> String? {
        items.first { $0.key == key && $0.category == category }?.value
    }

    public func items(forPersona personaID: String?) -> [MemoryItem] {
        let filtered = personaID.map { id in items.filter { $0.personaScope == nil || $0.personaScope == id } } ?? items
        return filtered.sorted {
            if $0.importance != $1.importance { return $0.importance > $1.importance }
            return $0.updatedAt > $1.updatedAt
        }
    }

    public func items(matching query: MemoryQuery, retentionThreshold: Double? = nil) -> [MemoryItem] {
        var effective = query
        if let retentionThreshold, effective.minimumImportance == nil {
            effective = MemoryQuery(category: query.category, personaScope: query.personaScope, minimumImportance: retentionThreshold, keyPrefix: query.keyPrefix, limit: query.limit)
        }
        return effective.apply(to: items)
    }

    public func delete(id: UUID) async {
        do {
            try await store.delete(id: id)
            items.removeAll { $0.id == id }
            await eventBus.publish(.memoryDidUpdate(itemID: id.uuidString))
        } catch {
            logger.error("Failed to delete memory item: \(error.localizedDescription)", category: logger.memory)
        }
    }

    @discardableResult
    public func clearAll() async -> Bool {
        for id in items.map(\.id) {
            await delete(id: id)
        }
        guard items.isEmpty else {
            logger.error("Memory clear failed; \(items.count) item(s) remain", category: logger.memory)
            return false
        }
        logger.info("Memory cleared by user request", category: logger.memory)
        return true
    }

    @discardableResult
    public func pruneBelow(importance threshold: Double) async -> Int {
        let victims = items.filter { $0.importance < threshold }
        for item in victims { await delete(id: item.id) }
        if !victims.isEmpty { logger.info("Pruned \(victims.count) memory items below importance \(threshold)", category: logger.memory) }
        return victims.count
    }

    public func exportJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        guard let json = String(data: data, encoding: .utf8) else { throw AppError.configurationMissing("Unable to encode memory export") }
        return json
    }

    private func persist(_ item: MemoryItem) async {
        do {
            try await store.save(item)
            if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item } else { items.append(item) }
            await eventBus.publish(.memoryDidUpdate(itemID: item.id.uuidString))
        } catch {
            logger.error("Failed to save memory item: \(error.localizedDescription)", category: logger.memory)
        }
    }
}
