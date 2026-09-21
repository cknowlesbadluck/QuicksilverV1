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

    @available(iOS 17.0, macOS 14.0, *)
    func testSwiftDataSaveLoadDelete() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let item1 = MemoryItem(key: "sd.1", category: .temporary, value: "v1")
        let item2 = MemoryItem(key: "sd.2", category: .preference, value: "v2")
        let item3 = MemoryItem(key: "sd.3", category: .temporary, value: "v3")

        try await store.save(item1)
        try await store.save(item2)
        try await store.save(item3)

        var loaded = try await store.loadAll()
        XCTAssertEqual(loaded.count, 3)

        try await store.delete(id: item1.id)
        loaded = try await store.loadAll()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertFalse(loaded.contains(where: { $0.id == item1.id }))

        try await store.deleteAll(in: .temporary)
        loaded = try await store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item2.id)
    }

    @available(iOS 17.0, macOS 14.0, *)
    func testSwiftDataBatchDeleteBenchmark() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let itemCount = 50

        for index in 0..<itemCount {
            let item = MemoryItem(key: "key-\(index)", category: .temporary, value: "value-\(index)")
            try await store.save(item)
        }

        // Keep 5 items in a different category
        for index in 0..<5 {
            let item = MemoryItem(key: "pref-\(index)", category: .preference, value: "pref-\(index)")
            try await store.save(item)
        }

        let beforeDelete = try await store.loadAll()
        XCTAssertEqual(beforeDelete.count, itemCount + 5)

        let startTime = CFAbsoluteTimeGetCurrent()
        try await store.deleteAll(in: .temporary)
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        let remaining = try await store.loadAll()
        XCTAssertEqual(remaining.count, 5)
        XCTAssertTrue(remaining.allSatisfy { $0.category == .preference })

        // Log baseline execution time for deleting items in category
        print("SwiftData MemoryStore category delete time for \(itemCount) items: \(elapsedTime * 1000) ms")
    }
}
