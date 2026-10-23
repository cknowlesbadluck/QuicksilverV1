import XCTest
@testable import Core
@testable import Memory

/// The real SwiftData store under the paths that only InMemoryMemoryStore covered before:
/// note migration, retention pruning, tolerant row decoding, concurrent upserts and ordering.
@MainActor
final class SwiftDataMemoryResilienceTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60

    private func manager(_ store: SwiftDataMemoryStore) -> MemoryManager {
        MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
    }

    // MARK: Migration (M4-T4) through SwiftData

    func testNoteMigrationPersistsInPlaceWithoutDuplicates() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let note = MemoryItem(key: "note.abc12345", category: .temporary, value: "Buy oat milk",
                              createdAt: created, updatedAt: created, importance: 0.2)
        try await store.save(note)

        await manager(store).load()

        let rows = try await store.loadAll()
        XCTAssertEqual(rows.count, 1, "migration updates the existing row, never inserts a second")
        XCTAssertEqual(rows.first?.id, note.id)
        XCTAssertEqual(rows.first?.category, .preference)
        XCTAssertEqual(rows.first?.createdAt, created)

        // Idempotent across a second launch.
        await manager(store).load()
        let again = try await store.loadAll()
        XCTAssertEqual(again.count, 1)
        XCTAssertEqual(again.first?.category, .preference)
    }

    // MARK: Retention (M4-T4) through SwiftData

    func testRetentionDeletesExpiredTurnsFromTheStoreButKeepsNotes() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let old = Date().addingTimeInterval(-400 * day)
        let fresh = Date().addingTimeInterval(-1 * day)
        try await store.save(MemoryItem(key: "chat.old", category: .conversation, value: "v", createdAt: old, updatedAt: old))
        try await store.save(MemoryItem(key: "chat.new", category: .conversation, value: "v", createdAt: fresh, updatedAt: fresh))
        try await store.save(MemoryItem(key: "pref.old", category: .preference, value: "tea", createdAt: old, updatedAt: old))
        try await store.save(MemoryItem(key: "chat.kept", category: .conversation, value: "v", createdAt: old, updatedAt: old,
                                        metadata: ["source": "user"]))

        await manager(store).load()

        let keys = try await Set(store.loadAll().map(\.key))
        XCTAssertEqual(keys, ["chat.new", "pref.old", "chat.kept"], "only the expired, non-user turn is gone from disk")
    }

    func testRetentionCapIsEnforcedOnTheStore() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let base = Date().addingTimeInterval(-day)
        for index in 0..<6 {
            let stamp = base.addingTimeInterval(TimeInterval(index))
            try await store.save(MemoryItem(key: "chat.\(index)", category: .conversation, value: "v",
                                            createdAt: stamp, updatedAt: stamp))
        }
        let memory = manager(store)
        memory.retention = MemoryRetentionPolicy(maxConversationItems: 4)

        await memory.load()

        let keys = try await Set(store.loadAll().map(\.key))
        XCTAssertEqual(keys, ["chat.2", "chat.3", "chat.4", "chat.5"], "the oldest turns go first")
    }

    // MARK: Tolerant decoding (corrupt or newer rows)

    func testCorruptMetadataBlobLoadsWithEmptyMetadata() {
        let entry = MemoryEntry(from: MemoryItem(key: "pref.x", category: .preference, value: "v", metadata: ["a": "b"]))
        entry.metadataData = Data("not json".utf8)
        let item = entry.toMemoryItem()
        XCTAssertEqual(item.value, "v")
        XCTAssertTrue(item.metadata.isEmpty, "a damaged blob must not drop the row")
    }

    func testUnknownCategoryFromANewerSchemaFallsBackToTemporary() {
        let entry = MemoryEntry(from: MemoryItem(key: "x", category: .preference, value: "v"))
        entry.categoryRaw = "category-from-the-future"
        XCTAssertEqual(entry.toMemoryItem().category, .temporary)
    }

    func testMissingMetadataLoadsWithEmptyMetadata() {
        let entry = MemoryEntry(from: MemoryItem(key: "x", category: .project, value: "v"))
        entry.metadataData = nil
        XCTAssertEqual(entry.toMemoryItem().metadata, [:])
    }

    // MARK: Concurrency and ordering

    func testConcurrentSavesOfOneIdKeepASingleRow() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let id = UUID()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    let item = MemoryItem(id: id, key: "pref.race", category: .preference, value: "v\(index)")
                    try? await store.save(item)
                }
            }
        }
        let rows = try await store.loadAll()
        XCTAssertEqual(rows.count, 1, "@Attribute(.unique) upsert must hold under concurrent writers")
        XCTAssertTrue(rows.first?.value.hasPrefix("v") == true)
    }

    func testLoadAllReturnsNewestFirst() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        for index in [2, 0, 1] {
            let stamp = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + index))
            try await store.save(MemoryItem(key: "k\(index)", category: .project, value: "v", createdAt: stamp, updatedAt: stamp))
        }
        let keys = try await store.loadAll().map(\.key)
        XCTAssertEqual(keys, ["k2", "k1", "k0"])
    }
}
