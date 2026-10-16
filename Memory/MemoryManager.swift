import Foundation
import Observation
import Core

@MainActor
@Observable
public final class MemoryManager {
    public private(set) var items: [MemoryItem] = []

    /// Most recent persistence failure, cleared by the next successful
    /// operation of the same kind. Surfaces store failures (M4-T5) instead
    /// of silently logging them; in-memory items stay authoritative.
    public enum Failure: String, Sendable, Equatable {
        case load, save, delete
    }
    public private(set) var lastFailure: Failure?

    private let store: MemoryStore
    /// True when SwiftData was unavailable and memory fell back to the Keychain store (diagnostics only).
    public var usesBackupStore: Bool { store is KeychainMemoryStore }
    /// M4-T4: applied on load and after a conversation write that exceeds the cap.
    public var retention: MemoryRetentionPolicy = .default
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
            if lastFailure == .load { lastFailure = nil }
            await migrateTemporaryNotes()
            logger.info("Loaded \(items.count) memory items", category: logger.memory)
            await applyRetention()
        } catch {
            lastFailure = .load
            logger.error("Failed to load memory: \(error.localizedDescription)", category: logger.memory)
        }
    }

    public func set(
        key: String,
        value: String,
        category: MemoryItem.Category,
        metadata: [String: String] = [:],
        importanceBoost: Double? = nil,
        personaScope: String? = nil
    ) async {
        if let existing = items.first(where: { $0.key == key && $0.category == category }) {
            var updated = existing
            updated.value = value
            updated.updatedAt = Date()
            updated.metadata = metadata
            updated.importance = MemoryScorer.score(
                category: category,
                value: value,
                explicitBoost: importanceBoost,
                existing: existing.importance
            )
            if let personaScope { updated.personaScope = personaScope }
            await persist(updated)
        } else {
            let importance = MemoryScorer.score(
                category: category,
                value: value,
                explicitBoost: importanceBoost
            )
            let item = MemoryItem(
                key: key,
                category: category,
                value: value,
                metadata: metadata,
                importance: importance,
                personaScope: personaScope
            )
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
            effective = MemoryQuery(
                category: query.category,
                personaScope: query.personaScope,
                minimumImportance: retentionThreshold,
                keyPrefix: query.keyPrefix,
                text: query.text,
                limit: query.limit
            )
        }
        return effective.apply(to: items)
    }

    public func delete(id: UUID) async {
        do {
            try await store.delete(id: id)
            items.removeAll { $0.id == id }
            if lastFailure == .delete { lastFailure = nil }
            await eventBus.publish(.memoryDidUpdate(itemID: id.uuidString))
        } catch {
            lastFailure = .delete
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

    /// Removes only what `retention` allows (conversation turns, by age and count).
    @discardableResult
    public func applyRetention(now: Date = Date()) async -> Int {
        let victims = retention.victims(in: items, now: now)
        for item in victims { await delete(id: item.id) }
        if !victims.isEmpty { logger.info("Retention pruned \(victims.count) conversation turns", category: logger.memory) }
        return victims.count
    }

    public func exportJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppError.configurationMissing("Unable to encode memory export")
        }
        return json
    }

    /// M4-T4: notes the user asked us to keep ("note.*" keys from Quick Note and
    /// "remember …") used to be stored as `.temporary`, which decays with a 2-day
    /// half-life. That silently lost user data. Move them to `.preference` once, and keep
    /// their id, value and timestamps. This is idempotent: migrated items are no longer `.temporary`.
    static func needsNoteMigration(_ item: MemoryItem) -> Bool {
        item.category == .temporary && item.key.hasPrefix("note.")
    }

    private func migrateTemporaryNotes() async {
        let pending = items.filter(Self.needsNoteMigration)
        guard !pending.isEmpty else { return }
        for old in pending {
            var metadata = old.metadata
            if metadata["source"] == nil { metadata["source"] = "user" }
            let floor = MemoryScorer.score(category: .preference, value: old.value)
            let migrated = MemoryItem(
                id: old.id,
                key: old.key,
                category: .preference,
                value: old.value,
                createdAt: old.createdAt,
                updatedAt: old.updatedAt,
                metadata: metadata,
                importance: max(old.importance, floor),
                personaScope: old.personaScope
            )
            await persist(migrated)
        }
        logger.info("Migrated \(pending.count) notes to durable memory", category: logger.memory)
    }

    private func persist(_ item: MemoryItem) async {
        do {
            try await store.save(item)
            if let index = items.firstIndex(where: { $0.id == item.id }) { items[index] = item } else { items.append(item) }
            if lastFailure == .save { lastFailure = nil }
            await eventBus.publish(.memoryDidUpdate(itemID: item.id.uuidString))
            if item.category == .conversation,
               items.lazy.filter(MemoryRetentionPolicy.isPrunable).count > retention.maxConversationItems {
                await applyRetention()
            }
        } catch {
            lastFailure = .save
            logger.error("Failed to save memory item: \(error.localizedDescription)", category: logger.memory)
        }
    }
}
