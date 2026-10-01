import XCTest
@testable import Quicksilver
import Core

@MainActor
final class ForgeViewModelTests: XCTestCase {
    func testAwakenProjectsForgeAspect() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = ForgeViewModel(container: container)
        XCTAssertFalse(vm.isAwake)

        try await container.brain.switchAspect(to: .forge)
        vm.refresh()

        XCTAssertEqual(vm.activeAspect, .forge)
        XCTAssertTrue(vm.isAwake)
        XCTAssertEqual(vm.activePersonaID, Aspect.forge.rawValue)
    }

    func testCaptureNoteStoresEntityWideMemory() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = ForgeViewModel(container: container)

        await vm.captureNote("  brace the joint  ")

        XCTAssertEqual(vm.sessionNotes, ["brace the joint"])
        await container.memoryManager.load()
        let values = container.memoryManager.items.map(\.value)
        XCTAssertTrue(values.contains("Forge note: brace the joint"))
        XCTAssertTrue(container.memoryManager.items.allSatisfy { $0.personaScope == nil })
    }

    func testBlankCaptureNoteDoesNotWrite() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = ForgeViewModel(container: container)

        await vm.captureNote("  \n  ")

        XCTAssertTrue(vm.sessionNotes.isEmpty)
        await container.memoryManager.load()
        XCTAssertTrue(container.memoryManager.items.isEmpty)
    }
}
