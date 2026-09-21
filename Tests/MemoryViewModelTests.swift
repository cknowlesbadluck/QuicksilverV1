import XCTest
#if canImport(Quicksilver)
@testable import Core
@testable import Memory
@testable import Personas
@testable import Quicksilver

@MainActor
final class MemoryViewModelTests: XCTestCase {

    func testClearAllSuccessfullyClearsItemsAndUpdatesStatusMessage() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("First memory note")
        await vm.addQuickNote("Second memory note")
        await vm.load()

        XCTAssertEqual(vm.items.count, 2)

        await vm.clearAll()

        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertEqual(container.memoryManager.items.count, 0)
        XCTAssertEqual(vm.statusMessage, "All memories cleared")
    }

    func testClearAllFailsWhenStoreDeleteFailsAndUpdatesStatusMessage() async {
        let store = FailingDeleteMemoryStore()
        let container = DependencyContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)

        let item = MemoryItem(key: "test.failing", category: .temporary, value: "persistent")
        try? await store.save(item)

        await vm.load()
        XCTAssertEqual(vm.items.count, 1)

        await vm.clearAll()

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.statusMessage, "Unable to clear all memories")
    }

    func testClearAllWhenStoreIsEmpty() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)

        await vm.load()
        XCTAssertTrue(vm.items.isEmpty)

        await vm.clearAll()

        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertEqual(vm.statusMessage, "All memories cleared")
    }

    func testLoadPopulatesItemsAndActivePolicyLabel() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("Policy test note")
        await vm.load()

        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.activePolicyLabel.isEmpty)
        XCTAssertFalse(vm.items.isEmpty)
    }

    func testAddQuickNoteIgnoresEmptyOrWhitespaceOnlyText() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("")
        await vm.addQuickNote("   \n  ")
        await vm.load()

        XCTAssertTrue(vm.items.isEmpty)
    }

    func testDeleteRemovesSpecificItemAndUpdatesStatusMessage() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("Keep me")
        await vm.addQuickNote("Delete me")
        await vm.load()

        XCTAssertEqual(vm.items.count, 2)

        guard let target = vm.items.first(where: { $0.value == "Delete me" }) else {
            XCTFail("Target item not found")
            return
        }

        await vm.delete(id: target.id)

        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.value, "Keep me")
        XCTAssertEqual(vm.statusMessage, "Memory deleted")
    }

    func testPrepareExportGeneratesJSONAndSetsStatusMessage() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("Export note")
        await vm.load()

        vm.prepareExport()

        XCTAssertNotNil(vm.lastExportJSON)
        XCTAssertTrue(vm.lastExportJSON?.contains("Export note") == true)
        XCTAssertEqual(vm.statusMessage, "Export ready")
    }
}

private actor FailingDeleteMemoryStore: MemoryStore {
    private var items: [MemoryItem] = []

    func loadAll() async throws -> [MemoryItem] {
        return items
    }

    func save(_ item: MemoryItem) async throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
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
#endif
