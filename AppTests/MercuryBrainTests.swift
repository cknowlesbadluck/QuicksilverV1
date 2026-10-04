import XCTest
@testable import Quicksilver
import Core
import Memory
import ServicesAI
import Nexus
import Personas

@MainActor
final class MercuryBrainTests: XCTestCase {
    func testAskHappyPathReportsThinkingThenSuccessThenBaseline() async throws {
        let gate = RequestGate()
        let harness = try makeHarness(provider: GatedProvider(gate: gate, reply: "Ready."))
        harness.container.featureFlags.set("aiServiceEnabled", enabled: true)

        let task = Task { try await harness.container.brain.ask("build a shelf") }
        await gate.waitUntilEntered()
        XCTAssertEqual(harness.container.brain.visualState, .thinking)

        gate.proceed()
        let reply = try await task.value
        XCTAssertEqual(reply, "Ready.")
        XCTAssertEqual(harness.container.brain.activeAspect, .forge)
        XCTAssertEqual(harness.container.brain.visualState, .success)

        try await Task.sleep(for: .milliseconds(800))
        // Forge's resting state is `.thinking` (Aspect.defaultVisualState).
        XCTAssertEqual(harness.container.brain.visualState, .thinking)
    }

    func testBrokerDenySetsWarningAndThrows() throws {
        let harness = try makeHarness(provider: GatedProvider(gate: RequestGate(), reply: "unused"))
        XCTAssertThrowsError(
            try harness.container.brain.enforceBrokerDecision(.deny(reason: "budget exhausted"))
        ) { error in
            guard case AppError.aiRequestFailed(let reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(reason, "budget exhausted")
        }
        XCTAssertEqual(harness.container.brain.visualState, .warning)
    }

    /// M3-T7: when Nexus reports disconnected, ask skips the provider and living status says so.
    func testAskOfflineFastFailsWithoutNetworkCall() async throws {
        let probe = CountingProvider()
        let harness = try makeHarness(provider: probe)
        harness.container.featureFlags.set("aiServiceEnabled", enabled: true)
        harness.container.nexus.noteNetworkCondition(isConnected: false)
        XCTAssertEqual(harness.container.nexus.state.networkStatus, "disconnected")

        do {
            _ = try await harness.container.brain.ask("build a shelf")
            XCTFail("Expected AppError.networkUnavailable while offline")
        } catch AppError.networkUnavailable {
            // expected
        } catch {
            return XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(probe.callCount, 0, "offline ask must not touch the AI provider")
        XCTAssertEqual(harness.container.brain.livingStatus, LivingNarration.offlineStatus)
        // Offline fast-fail does not enter `.thinking` / `.warning`.
        XCTAssertNotEqual(harness.container.brain.visualState, .thinking)
    }

    /// Offline must not mask unbound guidance — Ask still points at the Codex.
    func testAskOfflinePreservesUnboundError() async throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let harness = try makeHarness(provider: CountingProvider())
        // Clear injected providers without leaving Keychain unrestored (teardown restores).
        harness.container.aiService.clearAllAPIKeys()
        XCTAssertFalse(harness.container.aiService.isBound)
        harness.container.nexus.noteNetworkCondition(isConnected: false)

        do {
            _ = try await harness.container.brain.ask("build a shelf")
            XCTFail("Expected AppError.apiKeyMissing while unbound+offline")
        } catch AppError.apiKeyMissing {
            // expected — bind guidance wins over airplane-mode copy
        } catch {
            return XCTFail("Unexpected error: \(error)")
        }
    }

    func testRememberStoresEntityWideMemory() async throws {
        let harness = try makeHarness(provider: GatedProvider(gate: RequestGate(), reply: "unused"))
        await harness.container.brain.remember("Keep the injection seam small.")

        let stored = try await harness.store.loadAll()
        let match = stored.first(where: { $0.value == "Keep the injection seam small." })
        let item = try XCTUnwrap(match)
        XCTAssertNil(item.personaScope)
    }

    func testSwitchAspectProjectsPersonaAndPublishesEvent() async throws {
        let harness = try makeHarness(provider: GatedProvider(gate: RequestGate(), reply: "unused"))
        let stream = await harness.container.eventBus.events(bufferingNewest: 4) { event in
            if case .personaDidChange = event { return true }
            return false
        }

        try await harness.container.brain.switchAspect(to: .forge)

        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()
        guard case .personaDidChange(let personaID)? = event else {
            return XCTFail("Missing personaDidChange, got \(String(describing: event))")
        }
        XCTAssertEqual(personaID, Aspect.forge.rawValue)
        XCTAssertEqual(harness.container.brain.activeAspect, .forge)
        XCTAssertEqual(harness.container.personaManager.activePersonaID, Aspect.forge.rawValue)
    }

    func testAskSendsRecentHistoryAndDropsTurnsBeyondBudget() async throws {
        let recorder = RecordingProvider(reply: "Noted.")
        let harness = try makeHarness(provider: recorder)
        harness.container.featureFlags.set("aiServiceEnabled", enabled: true)

        _ = try await harness.container.brain.ask("turn-1")
        let first = recorder.histories
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0], [])

        for index in 2...10 {
            _ = try await harness.container.brain.ask("turn-\(index)")
        }

        let histories = recorder.histories
        XCTAssertEqual(histories.count, 10)
        XCTAssertEqual(histories[1].count, 2)
        XCTAssertEqual(histories[1][0], Message(role: .user, content: "turn-1"))
        XCTAssertEqual(histories[1][1].role, .assistant)
        XCTAssertEqual(histories[1][1].content, "Noted.")
        // 9 prior pairs would be 18 messages; budget keeps the newest 8 pairs.
        XCTAssertEqual(histories[9].count, 16)
        XCTAssertEqual(histories[9].first, Message(role: .user, content: "turn-2"))
        XCTAssertEqual(histories[9].last, Message(role: .assistant, content: "Noted."))
        XCTAssertFalse(histories[9].contains(Message(role: .user, content: "turn-1")))
    }

    func testFailedAskDoesNotPoisonConversationHistory() async throws {
        let recorder = RecordingProvider(reply: "unused", fail: true)
        let harness = try makeHarness(provider: recorder)
        harness.container.featureFlags.set("aiServiceEnabled", enabled: true)
        do {
            _ = try await harness.container.brain.ask("do not keep")
            XCTFail("expected provider failure")
        } catch {
            XCTAssertFalse(error is CancellationError)
        }
        recorder.fail = false
        _ = try await harness.container.brain.ask("keep this")
        XCTAssertEqual(recorder.histories.last, [])
    }

    private func makeHarness(provider: AIProvider) throws -> Harness {
        let suiteName = "MercuryBrainTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        let logger = LoggerService(subsystem: "com.quicksilver.tests")
        let eventBus = EventBus()
        let store = InMemoryMemoryStore()
        let nexus = NexusCoordinator(
            networkMonitor: StubNetworkMonitor(),
            batteryMonitor: StubBatteryMonitor(),
            storageMonitor: StubStorageMonitor(),
            deviceMonitor: StubDeviceMonitor(),
            logger: logger,
            eventBus: eventBus
        )
        let container = DependencyContainer(
            memoryStore: store,
            aiProvider: provider,
            nexus: nexus,
            defaults: defaults
        )
        return Harness(container: container, store: store)
    }
}

private struct Harness {
    let container: DependencyContainer
    let store: InMemoryMemoryStore
}

private final class RequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var entered: CheckedContinuation<Void, Never>?
    private var proceedWaiter: CheckedContinuation<Void, Never>?
    private var didEnter = false
    private var shouldProceed = false

    func waitUntilEntered() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if didEnter {
                lock.unlock()
                continuation.resume()
            } else {
                entered = continuation
                lock.unlock()
            }
        }
    }

    func markEntered() {
        lock.lock()
        didEnter = true
        let continuation = entered
        entered = nil
        lock.unlock()
        continuation?.resume()
    }

    func waitToProceed() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if shouldProceed {
                lock.unlock()
                continuation.resume()
            } else {
                proceedWaiter = continuation
                lock.unlock()
            }
        }
    }

    func proceed() {
        lock.lock()
        shouldProceed = true
        let continuation = proceedWaiter
        proceedWaiter = nil
        lock.unlock()
        continuation?.resume()
    }
}

private final class CountingProvider: AIProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    var callCount: Int {
        lock.withLock { _callCount }
    }

    let id = "counting"
    let displayName = "Counting"
    let isAvailable = true

    private func recordCall() {
        lock.withLock { _callCount += 1 }
    }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        recordCall()
        return AIResponse(requestID: request.id, content: "should-not-run")
    }
}

private final class RecordingProvider: AIProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _histories: [[Message]] = []
    var fail: Bool

    var histories: [[Message]] {
        lock.withLock { _histories }
    }

    let reply: String
    let id = "recording"
    let displayName = "Recording"
    let isAvailable = true

    init(reply: String, fail: Bool = false) {
        self.reply = reply
        self.fail = fail
    }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        let shouldFail = lock.withLock { () -> Bool in
            _histories.append(request.history)
            return fail
        }
        if shouldFail {
            throw AppError.aiRequestFailed("recording-fail")
        }
        return AIResponse(requestID: request.id, content: reply)
    }
}

private struct GatedProvider: AIProvider {
    let gate: RequestGate
    let reply: String
    let id = "gated"
    let displayName = "Gated"
    let isAvailable = true

    func complete(_ request: AIRequest) async throws -> AIResponse {
        gate.markEntered()
        await gate.waitToProceed()
        return AIResponse(requestID: request.id, content: reply)
    }
}

private final class StubNetworkMonitor: NetworkMonitoring {
    let diagnosticID = "network-test"
    var isConnected = true
    var isExpensive = false
    var isConstrained = false
    var onChange: ((Bool, Bool, Bool) -> Void)?
    func start() {}
    func stop() {}
}

private final class StubBatteryMonitor: BatteryMonitoring {
    let diagnosticID = "battery-test"
    var level = 1.0
    var stateDescription = "full"
    var onChange: ((Double, String) -> Void)?
    func start() {}
    func stop() {}
}

private final class StubStorageMonitor: StorageMonitoring {
    let diagnosticID = "storage-test"
    var availableGB = 100.0
    var totalGB = 128.0
    var onChange: ((Double, Double) -> Void)?
    func start() {}
    func stop() {}
}

private final class StubDeviceMonitor: DeviceMetricsMonitoring {
    let diagnosticID = "device-test"
    var thermalStateDescription = "nominal"
    var isLowPowerMode = false
    var onChange: ((String, Bool) -> Void)?
    func start() {}
    func stop() {}
}
