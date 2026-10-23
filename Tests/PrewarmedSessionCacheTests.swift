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

    func testInstructionChangeNeverReusesAnotherKeysSession() {
        let cache = PrewarmedSessionCache<FakeSession>()
        let warm = FakeSession()
        cache.store(warm, for: "aspect A")
        XCTAssertNil(cache.take(for: "aspect B"), "Aspect/system-prompt change must not reuse")
        XCTAssertTrue(cache.isWarm(for: "aspect A"), "A mismatch leaves the other warmed session alone")
        XCTAssertTrue(cache.take(for: "aspect A") === warm)
        XCTAssertFalse(cache.isWarm)
    }

    /// The #345 risk: a note summary must not evict the warmed chat session.
    func testSideTaskDoesNotEvictTheChatSession() {
        let cache = PrewarmedSessionCache<FakeSession>()
        let chat = FakeSession()
        cache.store(chat, for: "chat")
        XCTAssertNil(cache.take(for: "summary"))
        cache.store(FakeSession(), for: "summary") // the summary turn re-warms its own key
        XCTAssertEqual(cache.count, 2)
        XCTAssertTrue(cache.take(for: "chat") === chat)
    }

    func testCapacityEvictsTheLeastRecentlyStored() {
        let cache = PrewarmedSessionCache<FakeSession>(capacity: 2)
        cache.store(FakeSession(), for: "a")
        cache.store(FakeSession(), for: "b")
        cache.store(FakeSession(), for: "c")
        XCTAssertEqual(cache.count, 2)
        XCTAssertFalse(cache.isWarm(for: "a"))
        XCTAssertTrue(cache.isWarm(for: "b"))
        XCTAssertTrue(cache.isWarm(for: "c"))
    }

    func testStoringTheSameKeyReplacesAndRefreshesIt() {
        let cache = PrewarmedSessionCache<FakeSession>(capacity: 2)
        cache.store(FakeSession(), for: "a")
        cache.store(FakeSession(), for: "b")
        let fresh = FakeSession()
        cache.store(fresh, for: "a") // "a" is now the most recent
        cache.store(FakeSession(), for: "c") // evicts "b"
        XCTAssertFalse(cache.isWarm(for: "b"))
        XCTAssertTrue(cache.take(for: "a") === fresh)
    }

    func testCapacityIsAtLeastOne() {
        let cache = PrewarmedSessionCache<FakeSession>(capacity: 0)
        cache.store(FakeSession(), for: "a")
        XCTAssertEqual(cache.capacity, 1)
        XCTAssertEqual(cache.count, 1)
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
        cache.store(FakeSession(), for: "summary")
        cache.discard()
        XCTAssertNil(cache.take(for: nil))
        XCTAssertFalse(cache.isWarm, "memory pressure drops every warmed session")
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
