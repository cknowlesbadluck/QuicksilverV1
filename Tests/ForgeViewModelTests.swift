import XCTest
@testable import Core
@testable import Personas
@testable import Nexus
@testable import Memory
@testable import ServicesAI
@testable import QuicksilverIntents

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
        XCTAssertFalse(viewModel.isAwakening)

        let task = Task {
            await viewModel.awakenForge()
        }

        // Yield to allow task to start and set isAwakening to true
        await Task.yield()

        // As long as the task hasn't completed, it should be awakening or completed
        let awakeningState = viewModel.isAwakening
        let awakeState = viewModel.isAwake
        XCTAssertTrue(awakeningState || awakeState)

        // Action
        await task.value

        // Verification
        XCTAssertEqual(viewModel.activePersonaID, "forge")
        XCTAssertEqual(viewModel.activeAspect, .forge)
        XCTAssertTrue(viewModel.isAwake)
        XCTAssertFalse(viewModel.isAwakening)
        XCTAssertNotEqual(viewModel.livingStatus, "Workshop is dormant.")
    }
}
#endif
// Trigger CI
