import XCTest
@testable import Core
@testable import Memory

@MainActor
final class MemoryLifecycleTests: XCTestCase {

    func testDeleteRemovesItem() async {
        let store = InMemoryMemoryStore()
        let bus = EventBus()
        let logger = LoggerService()
        let manager = MemoryManager(store: store, eventBus: bus, logger: logger)

        await manager.set(key: "test.1", value: "hello", category: .temporary)
        XCTAssertEqual(manager.items.count, 1)

        let id = manager.items[0].id
        await manager.delete(id: id)
        XCTAssertTrue(manager.items.isEmpty)
    }

    func testBatchDeleteRemovesMultipleItems() async {
        let store = InMemoryMemoryStore()
        let bus = EventBus()
        let logger = LoggerService()
        let manager = MemoryManager(store: store, eventBus: bus, logger: logger)

        await manager.set(key: "item1", value: "v1", category: .temporary)
        await manager.set(key: "item2", value: "v2", category: .temporary)
        await manager.set(key: "item3", value: "v3", category: .temporary)

        let idsToDelete = Set(manager.items.prefix(2).map(\.id))
        await manager.delete(ids: idsToDelete)

        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.key, "item3")
    }

    func testClearAllEmptiesStore() async {
        let store = InMemoryMemoryStore()
        let bus = EventBus()
        let logger = LoggerService()
        let manager = MemoryManager(store: store, eventBus: bus, logger: logger)

        await manager.set(key: "a", value: "1", category: .temporary)
        await manager.set(key: "b", value: "2", category: .temporary)
        XCTAssertEqual(manager.items.count, 2)

        await manager.clearAll()
        XCTAssertTrue(manager.items.isEmpty)
    }

    func testPruneBelowRemovesLowImportanceItems() async {
        let store = InMemoryMemoryStore()
        let bus = EventBus()
        let logger = LoggerService()
        let manager = MemoryManager(store: store, eventBus: bus, logger: logger)

        await manager.set(key: "low1", value: "val1", category: .temporary, importanceBoost: -0.5)
        await manager.set(key: "low2", value: "val2", category: .temporary, importanceBoost: -0.5)
        await manager.set(key: "high", value: "val3", category: .preference, importanceBoost: 0.9)

        XCTAssertEqual(manager.items.count, 3)

        let prunedCount = await manager.pruneBelow(importance: 0.5)

        XCTAssertEqual(prunedCount, 2)
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(manager.items.first?.key, "high")
    }

    func testExportJSONProducesValidPayload() async throws {
        let store = InMemoryMemoryStore()
        let bus = EventBus()
        let logger = LoggerService()
        let manager = MemoryManager(store: store, eventBus: bus, logger: logger)

        await manager.set(key: "note", value: "export me", category: .temporary)
        let json = try manager.exportJSON()
        XCTAssertTrue(json.contains("export me"))
        XCTAssertTrue(json.contains("note"))
    }
}
