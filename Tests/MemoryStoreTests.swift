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

    func testInMemoryBatchDelete() async throws {
        let store = InMemoryMemoryStore()
        let item1 = MemoryItem(key: "del1", category: .temporary, value: "x")
        let item2 = MemoryItem(key: "del2", category: .temporary, value: "y")
        let item3 = MemoryItem(key: "keep", category: .temporary, value: "z")
        try await store.save(item1)
        try await store.save(item2)
        try await store.save(item3)

        try await store.delete(ids: [item1.id, item2.id])

        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.key, "keep")
    }

    func testUserDefaultsBatchDelete() async throws {
        let suiteName = "test.memory.batch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsMemoryStore(defaults: defaults)

        let item1 = MemoryItem(key: "ud1", category: .temporary, value: "x")
        let item2 = MemoryItem(key: "ud2", category: .temporary, value: "y")
        try await store.save(item1)
        try await store.save(item2)

        try await store.delete(ids: [item1.id, item2.id])

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
}
