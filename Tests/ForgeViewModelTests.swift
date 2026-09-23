import XCTest
@testable import Core
@testable import Personas
@testable import Nexus

#if canImport(Quicksilver)
@testable import Quicksilver

@MainActor
final class ForgeViewModelTests: XCTestCase {

    func testAwakenForgeSuccess() async throws {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        // Initial state
        XCTAssertEqual(viewModel.activeAspect, .quicksilver)
        XCTAssertFalse(viewModel.isAwake)

        // Action
        await viewModel.awakenForge()

        // Verification
        XCTAssertEqual(viewModel.activePersonaID, "forge")
        XCTAssertEqual(viewModel.activeAspect, .forge)
        XCTAssertTrue(viewModel.isAwake)

        // Verify living status is updated correctly.
        // It shouldn't be the default string but something formatted by the brain
        XCTAssertNotEqual(viewModel.livingStatus, "Workshop is dormant.")
    }
}
#endif
