import XCTest
@testable import Core
@testable import Memory

final class MemoryStoreTests: XCTestCase {

    func testInMemorySaveAndLoad() async throws {
        let store = InMemoryMemoryStore()
        let item = MemoryItem(key: "test.key", category: .preference, value: "value-1", importance: 0.8)

        try await store.save(item)
        let loaded = try await store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.key, "test.key")
        XCTAssertEqual(loaded.first!.importance, 0.8, accuracy: 0.001)
    }

    func testInMemoryUpdate() async throws {
        let store = InMemoryMemoryStore()
        var item = MemoryItem(key: "k", category: .project, value: "v1")
        try await store.save(item)

        item.value = "v2"
        item.importance = 0.9
        try await store.save(item)

        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.value, "v2")
        XCTAssertEqual(loaded.first!.importance, 0.9, accuracy: 0.001)
    }

    func testInMemoryDelete() async throws {
        let store = InMemoryMemoryStore()
        let item = MemoryItem(key: "del", category: .temporary, value: "x")
        try await store.save(item)
        try await store.delete(id: item.id)

        let loaded = try await store.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testDeleteAllInCategory() async throws {
        let store = InMemoryMemoryStore()
        try await store.save(MemoryItem(key: "a", category: .temporary, value: "1"))
        try await store.save(MemoryItem(key: "b", category: .preference, value: "2"))
        try await store.deleteAll(in: .temporary)

        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.category, .preference)
    }

    func testKeychainMemoryStoreSaveAndLoad() async throws {
        let testKey = "test.keychain.memory.\(UUID().uuidString)"
        defer { KeychainStore.delete(forKey: testKey) }

        let store = KeychainMemoryStore(storageKey: testKey, legacyDefaults: nil)
        let item = MemoryItem(key: "secret.preference", category: .preference, value: "secure-value", importance: 0.95)

        try await store.save(item)
        let loaded = try await store.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.key, "secret.preference")
        XCTAssertEqual(loaded.first?.value, "secure-value")

        try await store.delete(id: item.id)
        let loadedAfterDelete = try await store.loadAll()
        XCTAssertTrue(loadedAfterDelete.isEmpty)
    }

    func testKeychainMemoryStoreLegacyUserDefaultsMigration() async throws {
        let testKey = "test.legacy.memory.\(UUID().uuidString)"
        let suiteName = "test.suite.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            KeychainStore.delete(forKey: testKey)
        }

        let legacyItem = MemoryItem(key: "legacy.key", category: .userFact, value: "legacy-sensitive-value")
        let legacyData = try JSONEncoder().encode([legacyItem])
        defaults.set(legacyData, forKey: testKey)

        // Verify setup: defaults holds data, keychain is empty
        XCTAssertNotNil(defaults.data(forKey: testKey))
        XCTAssertNil(KeychainStore.data(forKey: testKey))

        let store = KeychainMemoryStore(storageKey: testKey, legacyDefaults: defaults)
        let loaded = try await store.loadAll()

        // Verify migration: loaded items retrieved correctly
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.key, "legacy.key")
        XCTAssertEqual(loaded.first?.value, "legacy-sensitive-value")

        // Verify post-migration posture: legacy data in defaults purged, now stored in Keychain
        XCTAssertNil(defaults.data(forKey: testKey), "Legacy plain-text data should be removed from UserDefaults")
        XCTAssertNotNil(KeychainStore.data(forKey: testKey), "Migrated data should now reside in Keychain")
    }
}
