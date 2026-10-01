import XCTest
@testable import Quicksilver
import Core

@MainActor
final class EternalViewModelTests: XCTestCase {
    func testAwakenProjectsEternalAspect() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = EternalViewModel(container: container)
        XCTAssertFalse(vm.isAwake)

        try await container.brain.switchAspect(to: .eternal)
        vm.refresh()

        XCTAssertEqual(vm.activeAspect, .eternal)
        XCTAssertTrue(vm.isAwake)
        XCTAssertEqual(vm.activePersonaID, Aspect.eternal.rawValue)
    }

    func testCaptureObservationStoresEntityWideMemory() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = EternalViewModel(container: container)

        await vm.captureObservation("  the joint held  ")

        XCTAssertEqual(vm.observations, ["the joint held"])
        await container.memoryManager.load()
        XCTAssertTrue(container.memoryManager.items.map(\.value).contains("Eternal observation: the joint held"))
        XCTAssertTrue(container.memoryManager.items.allSatisfy { $0.personaScope == nil })
    }
}
