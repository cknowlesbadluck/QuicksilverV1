import XCTest
@testable import Quicksilver
import Core

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
        await container.memoryManager.set(
            key: "note.spotlight-target",
            value: "Saved note outside the active aspect scope",
            category: .preference,
            importanceBoost: 0.01,
            personaScope: "forge"
        )
        let targetID = try XCTUnwrap(
            container.memoryManager.items(matching: MemoryQuery()).first(where: { $0.key == "note.spotlight-target" })?.id
        )
        let vm = MemoryViewModel(container: container)
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
