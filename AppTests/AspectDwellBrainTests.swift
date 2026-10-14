import XCTest
@testable import Quicksilver
import Core
import Memory
import ServicesAI
import Nexus

/// Priority 3 end to end: the Brain holds an aspect through dwell, and the
/// aspect plus its dwell clock survive a relaunch (a new container over the
/// same defaults).
@MainActor
final class AspectDwellBrainTests: XCTestCase {
    func testTurnInsideDwellHoldsAspect() async throws {
        let defaults = try makeDefaults()
        let container = makeContainer(defaults: defaults)
        container.featureFlags.set("aiServiceEnabled", enabled: true)

        _ = try await container.brain.ask("build a shelf")
        XCTAssertEqual(container.brain.activeAspect, .forge)

        // Immediately afterwards a recall intent must not ping-pong the entity.
        _ = try await container.brain.ask("recall the previous shelf plan")
        XCTAssertEqual(container.brain.activeAspect, .forge, "Dwell holds the current aspect")
    }

    func testExplicitSwitchOverridesDwell() async throws {
        let container = makeContainer(defaults: try makeDefaults())
        try await container.brain.switchAspect(to: .forge)
        try await container.brain.switchAspect(to: .eternal)
        XCTAssertEqual(container.brain.activeAspect, .eternal)
    }

    func testAspectSurvivesRelaunch() async throws {
        let defaults = try makeDefaults()
        let first = makeContainer(defaults: defaults)
        try await first.brain.switchAspect(to: .eternal)

        let relaunched = makeContainer(defaults: defaults)
        XCTAssertEqual(relaunched.brain.activeAspect, .eternal)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "AspectDwellBrainTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    private func makeContainer(defaults: UserDefaults) -> DependencyContainer {
        ViewModelTestSupport.makeContainer(provider: EchoProvider(), defaults: defaults)
    }
}

private struct EchoProvider: AIProvider {
    let id = "echo"
    let displayName = "Echo"
    let isAvailable = true
    func complete(_ request: AIRequest) async throws -> AIResponse {
        AIResponse(requestID: request.id, content: "Noted.")
    }
}
