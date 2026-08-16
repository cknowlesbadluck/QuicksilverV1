import XCTest
@testable import Core
@testable import Memory

@MainActor
final class MemoryManagerTests: XCTestCase {
    func testSetAndRetrievePreference() async {
        let store = UserDefaultsMemoryStore(defaults: UserDefaults(suiteName: "test.memory")!)
        let bus = EventBus()
        let logger = LoggerService()
        let manager = MemoryManager(store: store, eventBus: bus, logger: logger)
        await manager.set(key: "theme", value: "dark", category: .preference)
        await manager.load()
        XCTAssertEqual(manager.value(for: "theme", category: .preference), "dark")
    }

    func testClearAllRetainsItemsWhenPersistenceDeleteFails() async {
        let store = FailingDeleteMemoryStore()
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.set(key: "theme", value: "dark", category: .preference)

        let didClear = await manager.clearAll()

        XCTAssertFalse(didClear)
        XCTAssertEqual(manager.items.count, 1)
        XCTAssertEqual(await store.loadAll().count, 1)
    }
}

private actor FailingDeleteMemoryStore: MemoryStore {
    private var items: [MemoryItem] = []

    func loadAll() async throws -> [MemoryItem] { items }

    func save(_ item: MemoryItem) async throws {
        if let index = items.firstIndex(where: { $0.id == item.id) } {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func delete(id: UUID) async throws {
        throw TestError.deleteFailed
    }

    func deleteAll(in category: MemoryItem.Category) async throws {
        throw TestError.deleteFailed
    }

    enum TestError: Error {
        case deleteFailed
    }
}
