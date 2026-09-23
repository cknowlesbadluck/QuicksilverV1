#if canImport(Quicksilver)
import XCTest
@testable import Quicksilver
import Core
import Personas
import Nexus
import Memory
import ServicesAI

@MainActor
final class HomeViewModelTests: XCTestCase {

    var container: DependencyContainer!
    var viewModel: HomeViewModel!

    override func setUp() async throws {
        try await super.setUp()
        container = DependencyContainer()
        viewModel = HomeViewModel(container: container)
    }

    override func tearDown() async throws {
        viewModel.stopLiveRefresh()
        viewModel = nil
        container = nil
        try await super.tearDown()
    }

    func testStartLiveRefreshRepeatedlyCallsRefresh() async throws {
        // Mock DependencyContainer could be useful but we don't have a protocol here.
        // Instead, we will directly observe that refresh runs. We can track its effects or at least
        // verify that the task runs without crashing. To properly test that refresh is called periodically,
        // we can set a state property on the container's nexus manually, and observe if it syncs back
        // to the view model due to the live refresh loop.

        let initialScore = viewModel.overallHealthScore

        // Start live refresh with a very short interval
        viewModel.startLiveRefresh(interval: .milliseconds(10))

        // Trigger a change in the dependency
        container.nexus.start() // should change isNexusActive to true.

        // Without live refresh, viewModel.isNexusActive would remain false unless we explicitly called refresh().
        // With live refresh, it should pick up the change.

        let expectation = XCTestExpectation(description: "Wait for refresh cycles to pick up state change")

        // Poll for the expected change
        for _ in 0..<20 {
            if viewModel.isNexusActive == true {
                expectation.fulfill()
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertTrue(viewModel.isNexusActive, "Live refresh should have picked up the nexus state change.")

        container.nexus.stop()
    }

    func testStartLiveRefreshReplacesOldTask() async throws {
        // Calling it twice shouldn't leak or crash. The first task is cancelled.
        viewModel.startLiveRefresh(interval: .milliseconds(10))
        viewModel.startLiveRefresh(interval: .milliseconds(10))

        container.nexus.start()

        let expectation = XCTestExpectation(description: "Wait for replacement task to work")
        for _ in 0..<20 {
            if viewModel.isNexusActive == true {
                expectation.fulfill()
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertTrue(viewModel.isNexusActive, "Replaced task should still function properly.")
        container.nexus.stop()
    }

    func testStopLiveRefresh() async throws {
        viewModel.startLiveRefresh(interval: .milliseconds(10))

        // Stop it
        viewModel.stopLiveRefresh()

        // Wait a bit to ensure the task has stopped completely
        try await Task.sleep(for: .milliseconds(30))

        // Change the underlying state
        container.nexus.start()

        // Wait to see if live refresh runs (it shouldn't)
        try await Task.sleep(for: .milliseconds(50))

        // The view model should not have picked up the change since refresh is stopped
        XCTAssertFalse(viewModel.isNexusActive, "View model should not pick up changes after live refresh is stopped.")

        // Calling stop again should be a safe no-op
        viewModel.stopLiveRefresh()

        container.nexus.stop()
    }
}
#endif
