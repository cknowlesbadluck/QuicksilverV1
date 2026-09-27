import XCTest
@testable import Core
@testable import QuicksilverIntents

/// M1-T6: Intents route exclusively through `IntelligenceSurface`.
@MainActor
final class IntentsTests: XCTestCase {

    private var fake: FakeIntelligenceSurface!

    override func setUp() async throws {
        fake = FakeIntelligenceSurface()
        IntentDependencies.shared.resetForTesting()
        IntentDependencies.shared.configure(surface: fake)
    }

    override func tearDown() async throws {
        IntentDependencies.shared.resetForTesting()
        fake = nil
    }

    func testForceAspectRoutesToSwitchAspect() async throws {
        let intent = ForceAspectIntent(
            aspect: AspectEntity(id: "forge", displayName: "Forge")
        )
        _ = try await intent.perform()
        XCTAssertEqual(fake.switchAspectCalls, [.forge])
    }

    func testCaptureMemoryRoutesToRemember() async throws {
        let intent = CaptureMemoryIntent(content: "ship M1-T6")
        _ = try await intent.perform()
        XCTAssertEqual(fake.rememberCalls, ["ship M1-T6"])
    }

    func testQueryNexusRoutesToAsk() async throws {
        fake.askResult = "use actors for Keychain"
        let intent = QueryNexusIntent(query: "how should I store keys?")
        _ = try await intent.perform()
        XCTAssertEqual(fake.askCalls, ["how should I store keys?"])
    }

    func testSwitchToForgeRoutesToSwitchAspect() async throws {
        let intent = SwitchToForgeIntent()
        _ = try await intent.perform()
        XCTAssertEqual(fake.switchAspectCalls, [.forge])
    }

    func testUnconfiguredSurfaceThrows() async {
        IntentDependencies.shared.resetForTesting()
        let intent = QueryNexusIntent(query: "ping")
        do {
            _ = try await intent.perform()
            XCTFail("expected nexusNotReady")
        } catch let error as AppError {
            guard case .nexusNotReady = error else {
                return XCTFail("unexpected AppError: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

// MARK: - Fake surface

@MainActor
private final class FakeIntelligenceSurface: IntelligenceSurface {
    var askCalls: [String] = []
    var rememberCalls: [String] = []
    var switchAspectCalls: [Aspect] = []
    var askResult: String = "fake-answer"
    var activeAspect: Aspect = .quicksilver
    var memories: [MemoryItem] = []
    var statusText: String = "Health 100"

    func ask(_ query: String) async throws -> String {
        askCalls.append(query)
        return askResult
    }

    func remember(_ content: String) async {
        rememberCalls.append(content)
    }

    func snapshot(limit: Int) -> [MemoryItem] {
        Array(memories.prefix(limit))
    }

    func switchAspect(to aspect: Aspect) async throws {
        switchAspectCalls.append(aspect)
        activeAspect = aspect
    }

    func statusReport() throws -> String {
        "\(activeAspect.diagnosticLabel) (\(activeAspect.rawValue)) | \(statusText)"
    }
}
