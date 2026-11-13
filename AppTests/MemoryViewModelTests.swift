import XCTest
@testable import Quicksilver
import Core
import Memory

@MainActor
final class MemoryViewModelTests: XCTestCase {
    func testLoadClearAndExport() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("  keep the seam small  ")
        XCTAssertEqual(vm.items.map(\.value), ["keep the seam small"])
        XCTAssertFalse(vm.isLoading)

        vm.prepareExport()
        let json = try XCTUnwrap(vm.lastExportJSON)
        XCTAssertTrue(json.contains("keep the seam small"))
        XCTAssertEqual(vm.statusMessage, "Export ready")

        await vm.clearAll()
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertEqual(vm.statusMessage, "All memories cleared")
    }

    func testSpotlightFocusedNoteIsLoadedOutsideTheScopedView() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)
        await vm.addQuickNote("note from another aspect")
        let id = try XCTUnwrap(vm.items.first?.id)
        try await container.personaManager.switchTo(id: "forge")

        await vm.load(focusing: id)
        XCTAssertTrue(vm.items.contains { $0.id == id }, "the Spotlight target must be in the Archive")
        XCTAssertEqual(vm.items.filter { $0.id == id }.count, 1, "never duplicated")
    }

    func testSpotlightFocusSurvivesUnrelatedArchiveReloads() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        try await container.personaManager.switchTo(id: "forge")
        await container.memoryManager.set(
            key: "note.spotlight-target",
            value: "Saved note outside the active aspect scope",
            category: .preference,
            importanceBoost: 0.1,
            personaScope: "quicksilver"
        )
        let targetID = try XCTUnwrap(
            container.memoryManager.items(matching: MemoryQuery()).first(where: { $0.key == "note.spotlight-target" })?.id
        )
        let vm = MemoryViewModel(container: container)
        await vm.load()
        XCTAssertFalse(vm.items.contains(where: { $0.id == targetID }), "fixture must be hidden by the active aspect scope")
        await vm.load(focusing: targetID)
        XCTAssertTrue(vm.items.contains(where: { $0.id == targetID }))

        await vm.addQuickNote("unrelated new note")
        XCTAssertTrue(vm.items.contains(where: { $0.id == targetID }), "adding a note must preserve the Spotlight target")

        let unrelatedID = try XCTUnwrap(vm.items.first(where: { $0.value == "unrelated new note" })?.id)
        await vm.delete(id: unrelatedID)
        XCTAssertTrue(vm.items.contains(where: { $0.id == targetID }), "deleting another note must preserve the Spotlight target")

        await vm.delete(id: targetID)
        XCTAssertFalse(vm.items.contains(where: { $0.id == targetID }), "deleting the focused note must clear the target")
    }


    func testFailedDeletePreservesSpotlightFocusAndReportsFailure() async throws {
        let store = TestMemoryStore()
        let container = try makeContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)
        await vm.addQuickNote("keep focus when delete fails")
        let id = try XCTUnwrap(vm.items.first?.id)
        await vm.load(focusing: id)
        await store.setDeleteFailures(true)

        await vm.delete(id: id)

        XCTAssertTrue(vm.items.contains { $0.id == id }, "a failed delete must preserve the saved focused note")
        XCTAssertEqual(vm.statusMessage, "Unable to delete memory")
    }

    func testFailedClearAllPreservesSpotlightFocus() async throws {
        let store = TestMemoryStore()
        let container = try makeContainer(memoryStore: store)
        let vm = MemoryViewModel(container: container)
        await vm.addQuickNote("keep focus when clear fails")
        let id = try XCTUnwrap(vm.items.first?.id)
        await vm.load(focusing: id)
        await store.setDeleteFailures(true)

        await vm.clearAll()

        XCTAssertTrue(vm.items.contains { $0.id == id }, "a partial clear must not discard a note that remains saved")
        XCTAssertEqual(vm.statusMessage, "Unable to clear all memories")
    }

    func testCancelledLoadClearsLoadingStateWithoutStompingNewerLoad() async throws {
        let store = TestMemoryStore()
        let container = try makeContainer(memoryStore: store)
        for _ in 0..<100 where !container.noteSpotlight.isMemoryReady {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let vm = MemoryViewModel(container: container)
        let baselineLoads = await store.loadCount()
        await store.delayNextLoad()

        let cancelledLoad = Task { await vm.load() }
        for _ in 0..<100 {
            if await store.loadCount() > baselineLoads { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(vm.isLoading)
        cancelledLoad.cancel()
        await cancelledLoad.value
        XCTAssertFalse(vm.isLoading, "cancelled loads must release their own loading state")
    }

    private func makeContainer(memoryStore: TestMemoryStore) throws -> DependencyContainer {
        let suiteName = "MemoryViewModelFailureTests.\\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return ViewModelTestSupport.makeContainer(provider: nil, defaults: defaults, memoryStore: memoryStore)
    }

    func testBlankNoteDoesNotWrite() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("   ")
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertNil(vm.lastExportJSON)
    }

    func testHealthyInjectedStoreShowsNoNotices() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)
        await vm.load()
        XCTAssertNil(vm.failureNotice)
        XCTAssertNil(vm.backupStoreNotice, "injected store is not the Keychain backup")
    }
}


private actor TestMemoryStore: MemoryStore {
    private enum Failure: Error { case delete }
    private var items: [MemoryItem] = []
    private var failDeletes = false
    private var delayNextLoad = false
    private var loads = 0

    func loadAll() async throws -> [MemoryItem] {
        loads += 1
        if delayNextLoad {
            delayNextLoad = false
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
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
        if failDeletes { throw Failure.delete }
        items.removeAll { $0.id == id }
    }

    func deleteAll(in category: MemoryItem.Category) async throws {
        if failDeletes { throw Failure.delete }
        items.removeAll { $0.category == category }
    }

    func setDeleteFailures(_ enabled: Bool) { failDeletes = enabled }
    func delayNextLoad() { delayNextLoad = true }
    func loadCount() -> Int { loads }
}
