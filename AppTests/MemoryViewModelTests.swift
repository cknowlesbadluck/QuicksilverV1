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

    func testBlankNoteDoesNotWrite() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("   ")
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertNil(vm.lastExportJSON)
    }
}
