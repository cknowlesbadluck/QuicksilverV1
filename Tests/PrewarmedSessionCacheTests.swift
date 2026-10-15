import Synchronization
import XCTest
@testable import Core
@testable import ServicesAI

/// M3.5-T4 follow-up: warmed on-device session reuse with strict invalidation.
final class PrewarmedSessionCacheTests: XCTestCase {
    private final class FakeSession: Sendable {
        let id = UUID()
    }

    func testMatchingInstructionsReuseTheWarmSession() {
        let cache = PrewarmedSessionCache<FakeSession>()
        let warm = FakeSession()
        cache.store(warm, for: "aspect A")
        XCTAssertTrue(cache.take(for: "aspect A") === warm)
    }

    func testInstructionChangeDropsTheStaleSession() {
        let cache = PrewarmedSessionCache<FakeSession>()
        cache.store(FakeSession(), for: "aspect A")
        XCTAssertNil(cache.take(for: "aspect B"), "Aspect/system-prompt change must not reuse")
        XCTAssertFalse(cache.isWarm, "The mismatched session is discarded, not kept around")
        XCTAssertNil(cache.take(for: "aspect A"))
    }

    func testSessionIsSingleUseSoTranscriptsCannotLeakAcrossTurns() {
        let cache = PrewarmedSessionCache<FakeSession>()
        cache.store(FakeSession(), for: "x")
        XCTAssertNotNil(cache.take(for: "x"))
        XCTAssertNil(cache.take(for: "x"), "A used session must never be handed out again")
    }

    func testDiscardOnMemoryPressure() {
        let cache = PrewarmedSessionCache<FakeSession>()
        cache.store(FakeSession(), for: nil)
        cache.discard()
        XCTAssertNil(cache.take(for: nil))
    }

    func testNilAndEmptyInstructionsShareAKey() {
        let cache = PrewarmedSessionCache<FakeSession>()
        cache.store(FakeSession(), for: nil)
        XCTAssertNotNil(cache.take(for: ""))
    }

    @MainActor
    func testAIServiceReleaseForwardsToTheModel() {
        let model = DiscardCountingModel()
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "PrewarmCache.\(UUID().uuidString)") ?? .standard)
        let service = AIService(primary: nil, secondary: nil, eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        service.onDeviceProvider = OnDeviceAIProvider(model: model)
        service.releaseOnDeviceResources()
        XCTAssertEqual(model.discards, 1)
    }
}

private final class DiscardCountingModel: OnDeviceLanguageModel {
    private let count = Mutex(0)
    var discards: Int { count.withLock { $0 } }
    var availability: OnDeviceModelAvailability { .available }
    func respond(instructions: String?, prompt: String) async throws -> String { "ok" }
    func discardPrewarmed() { count.withLock { $0 += 1 } }
}
