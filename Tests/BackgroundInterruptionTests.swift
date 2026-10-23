import Synchronization
import XCTest
@testable import Core
@testable import ServicesAI

/// Phase 9: backgrounding while a turn is in flight. `QuicksilverApp` calls
/// `releaseOnDeviceResources()` on `.background`; the in-flight turn must still finish or fail
/// typed, never wedge `isProcessing`, and never duplicate text.
@MainActor
final class BackgroundInterruptionTests: XCTestCase {
    private func service(model: OnDeviceLanguageModel, cloud: AIProvider? = nil) -> AIService {
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "BackgroundInterruption.\(UUID().uuidString)") ?? .standard)
        flags.set("aiServiceEnabled", enabled: true)
        let svc = AIService(primary: cloud, secondary: nil, eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        svc.onDeviceProvider = OnDeviceAIProvider(model: model)
        svc.retrySleep = { _ in }
        return svc
    }

    func testReleasingResourcesMidGenerationStillDeliversTheReply() async throws {
        let model = GatedModel()
        let svc = service(model: model)
        let turn = Task { try await svc.complete(AIRequest(prompt: "plan the shelf")) }
        await model.waitUntilStarted()
        XCTAssertTrue(svc.isProcessing)

        svc.releaseOnDeviceResources() // what .background does
        XCTAssertEqual(model.discards, 1)
        model.open()

        let response = try await turn.value
        XCTAssertEqual(response.content, "local reply")
        XCTAssertFalse(svc.isProcessing, "never wedged after backgrounding")
        XCTAssertEqual(svc.lastAnswerProvenance, .onDevice)
    }

    func testCancellingAfterBackgroundIsCleanAndUntyped() async throws {
        let model = GatedModel()
        let svc = service(model: model)
        let turn = Task { try await svc.complete(AIRequest(prompt: "plan the shelf")) }
        await model.waitUntilStarted()
        svc.releaseOnDeviceResources()
        turn.cancel()
        model.open()
        do {
            _ = try await turn.value
        } catch {
            XCTAssertTrue(error is CancellationError, "cancellation stays cancellation, got \(error)")
        }
        XCTAssertFalse(svc.isProcessing)
    }
}

/// On-device fake that blocks inside `respond` until `open()` is called.
private final class GatedModel: OnDeviceLanguageModel, Sendable {
    private struct State {
        var started = false
        var opened = false
        var discards = 0
        var startWaiters: [CheckedContinuation<Void, Never>] = []
        var openWaiters: [CheckedContinuation<Void, Never>] = []
    }
    private let state = Mutex(State())

    var availability: OnDeviceModelAvailability { .available }
    var discards: Int { state.withLock { $0.discards } }

    func respond(instructions: String?, prompt: String) async throws -> String {
        let waiters = state.withLock { s -> [CheckedContinuation<Void, Never>] in
            s.started = true
            defer { s.startWaiters = [] }
            return s.startWaiters
        }
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            let resumeNow = state.withLock { s -> Bool in
                if s.opened { return true }
                s.openWaiters.append(continuation)
                return false
            }
            if resumeNow { continuation.resume() }
        }
        try Task.checkCancellation()
        return "local reply"
    }

    func discardPrewarmed() { state.withLock { $0.discards += 1 } }

    func waitUntilStarted() async {
        await withCheckedContinuation { continuation in
            let resumeNow = state.withLock { s -> Bool in
                if s.started { return true }
                s.startWaiters.append(continuation)
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func open() {
        let waiters = state.withLock { s -> [CheckedContinuation<Void, Never>] in
            s.opened = true
            defer { s.openWaiters = [] }
            return s.openWaiters
        }
        waiters.forEach { $0.resume() }
    }
}
