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

    func testBlankNoteDoesNotWrite() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)

        await vm.addQuickNote("   ")
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertNil(vm.lastExportJSON)
    }
}
