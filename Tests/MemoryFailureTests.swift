import XCTest
@testable import Core
@testable import Memory

/// Priority 5/8: memory-store failure is surfaced and never crashes or
/// corrupts in-memory state.
@MainActor
final class MemoryFailureTests: XCTestCase {
    func testLoadFailureIsSurfacedAndKeepsItemsEmpty() async {
        let store = ToggleMemoryStore(failing: true)
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.load()
        XCTAssertEqual(manager.lastFailure, .load)
        XCTAssertTrue(manager.items.isEmpty)

        await store.setFailing(false)
        await manager.load()
        XCTAssertNil(manager.lastFailure, "Recovery clears the failure")
    }

    func testSaveFailureDoesNotInsertPhantomItem() async {
        let store = ToggleMemoryStore(failing: true)
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.set(key: "k", value: "v", category: .preference)
        XCTAssertEqual(manager.lastFailure, .save)
        XCTAssertNil(manager.value(for: "k", category: .preference))

        await store.setFailing(false)
        await manager.set(key: "k", value: "v", category: .preference)
        XCTAssertNil(manager.lastFailure)
        XCTAssertEqual(manager.value(for: "k", category: .preference), "v")
    }

    func testDeleteFailureKeepsItemAndSurfaces() async {
        let store = ToggleMemoryStore(failing: false)
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.set(key: "k", value: "v", category: .preference)
        await store.setFailing(true)
        let cleared = await manager.clearAll()
        XCTAssertFalse(cleared)
        XCTAssertEqual(manager.lastFailure, .delete)
        XCTAssertEqual(manager.items.count, 1)
    }

    func testInMemoryFallbackStoreRoundTrips() async throws {
        let manager = MemoryManager(store: InMemoryMemoryStore(), eventBus: EventBus(), logger: LoggerService())
        await manager.set(key: "fallback", value: "ok", category: .preference)
        await manager.load()
        XCTAssertEqual(manager.value(for: "fallback", category: .preference), "ok")
        XCTAssertNil(manager.lastFailure)
    }
}

private actor ToggleMemoryStore: MemoryStore {
    private var failing: Bool
    private var items: [MemoryItem] = []
    init(failing: Bool) { self.failing = failing }
    func setFailing(_ value: Bool) { failing = value }

    func loadAll() async throws -> [MemoryItem] {
        if failing { throw StoreError.unavailable }
        return items
    }
    func save(_ item: MemoryItem) async throws {
        if failing { throw StoreError.unavailable }
        items.removeAll { $0.id == item.id }
        items.append(item)
    }
    func delete(id: UUID) async throws {
        if failing { throw StoreError.unavailable }
        items.removeAll { $0.id == id }
    }
    func deleteAll(in category: MemoryItem.Category) async throws {
        if failing { throw StoreError.unavailable }
        items.removeAll { $0.category == category }
    }
    enum StoreError: Error { case unavailable }
}
