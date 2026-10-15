import XCTest
@testable import Core
@testable import Memory

/// M4-T4: user notes must not decay as `.temporary`.
@MainActor
final class MemoryNoteMigrationTests: XCTestCase {
    func testLoadMigratesTemporaryNotesToPreferenceKeepingIdentity() async throws {
        let store = InMemoryMemoryStore()
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let note = MemoryItem(key: "note.abc12345", category: .temporary, value: "Buy oat milk",
                              createdAt: created, updatedAt: created, importance: 0.2, personaScope: "mercury")
        let scratch = MemoryItem(key: "scratch.turn", category: .temporary, value: "ephemeral")
        try await store.save(note)
        try await store.save(scratch)

        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.load()

        let migrated = try XCTUnwrap(manager.items.first { $0.id == note.id })
        XCTAssertEqual(migrated.category, .preference)
        XCTAssertEqual(migrated.value, "Buy oat milk")
        XCTAssertEqual(migrated.createdAt, created)
        XCTAssertEqual(migrated.personaScope, "mercury")
        XCTAssertEqual(migrated.metadata["source"], "user")
        XCTAssertGreaterThan(migrated.importance, 0.2)
        XCTAssertEqual(manager.items.first { $0.id == scratch.id }?.category, .temporary)

        let persisted = try await store.loadAll()
        XCTAssertEqual(persisted.first { $0.id == note.id }?.category, .preference)
        XCTAssertEqual(persisted.count, 2, "migration must not duplicate or delete items")
    }

    func testMigrationKeepsExistingSourceAndIsIdempotent() async throws {
        let store = InMemoryMemoryStore()
        let note = MemoryItem(key: "note.brain.1", category: .temporary, value: "remember x",
                              metadata: ["source": "mercury-brain"])
        try await store.save(note)
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.load()
        await manager.load()
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.metadata["source"], "mercury-brain")
        XCTAssertFalse(manager.items.contains(where: MemoryManager.needsNoteMigration))
    }
}
