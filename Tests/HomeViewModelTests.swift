import XCTest
@testable import Core
@testable import Personas
@testable import App
@testable import UI

@MainActor
final class HomeViewModelTests: XCTestCase {

    func testInitialStateLoadsActiveConfiguration() {
        let container = DependencyContainer()
        let viewModel = HomeViewModel(container: container)

        XCTAssertEqual(viewModel.activePersonaID, "quicksilver")
        XCTAssertEqual(viewModel.personaDisplayName, "Quicksilver")
        XCTAssertFalse(viewModel.personaDescription.isEmpty)
        XCTAssertEqual(viewModel.availablePersonas.count, 3)
        XCTAssertNil(viewModel.lastSwitchReason)
        XCTAssertTrue(viewModel.livingStatus.contains("Quicksilver"))
    }

    func testSwitchPersonaToForge() async {
        let container = DependencyContainer()
        let viewModel = HomeViewModel(container: container)

        XCTAssertEqual(viewModel.activePersonaID, "quicksilver")

        viewModel.switchPersona(to: "forge")

        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.activePersonaID, "forge")
        XCTAssertEqual(viewModel.personaDisplayName, "Forge")
        XCTAssertEqual(container.activeConfiguration.id, "forge")
        XCTAssertNotNil(viewModel.lastSwitchReason)
    }

    func testSwitchPersonaToSameIDIsNoOp() async {
        let container = DependencyContainer()
        let viewModel = HomeViewModel(container: container)

        XCTAssertEqual(viewModel.activePersonaID, "quicksilver")

        viewModel.switchPersona(to: "quicksilver")
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.activePersonaID, "quicksilver")
        XCTAssertNil(viewModel.lastSwitchReason)
    }

    func testSwitchPersonaToUnknownID() async {
        let container = DependencyContainer()
        let viewModel = HomeViewModel(container: container)

        XCTAssertEqual(viewModel.activePersonaID, "quicksilver")

        viewModel.switchPersona(to: "invalid_persona_id")
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.activePersonaID, "quicksilver")
    }

    func testSwitchPersonaSequentially() async {
        let container = DependencyContainer()
        let viewModel = HomeViewModel(container: container)

        viewModel.switchPersona(to: "forge")
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(viewModel.activePersonaID, "forge")

        viewModel.switchPersona(to: "eternal")
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(viewModel.activePersonaID, "eternal")
        XCTAssertEqual(viewModel.personaDisplayName, "Eternal")
    }

    func testLiveRefreshStartAndStop() async {
        let container = DependencyContainer()
        let viewModel = HomeViewModel(container: container)

        viewModel.startLiveRefresh(interval: .milliseconds(50))
        try? await Task.sleep(for: .milliseconds(120))

        viewModel.stopLiveRefresh()
    }
}
