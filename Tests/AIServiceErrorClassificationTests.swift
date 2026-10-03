import XCTest
@testable import Core
@testable import ServicesAI

/// M3-T5: typed errors, one bounded retry before first delta, incomplete partials, no cancel retry.
@MainActor
final class AIServiceErrorClassificationTests: XCTestCase {

    func testUserFacingMessagesNameNoProvider() {
        let cases: [AppError] = [
            .rateLimited(retryAfter: 2),
            .unauthorized,
            .providerUnavailable,
            .budgetExhausted,
            .timedOut
        ]
        for error in cases {
            let text = error.localizedDescription
            XCTAssertFalse(text.isEmpty, "\(error)")
            XCTAssertFalse(text.contains("Gateway"), text)
            XCTAssertFalse(text.contains("Grok"), text)
            XCTAssertFalse(text.contains("Gemini"), text)
            XCTAssertFalse(text.contains("Groq"), text)
        }
    }

    func testRetryDelayHonorsRetryAfterCappedAtFive() {
        XCTAssertEqual(
            AIClientClassifier.retryDelaySeconds(for: AppError.rateLimited(retryAfter: 2)),
            2
        )
        XCTAssertEqual(
            AIClientClassifier.retryDelaySeconds(for: AppError.rateLimited(retryAfter: 30)),
            5
        )
        XCTAssertEqual(
            AIClientClassifier.retryDelaySeconds(for: AppError.rateLimited(retryAfter: nil)),
            0
        )
        XCTAssertEqual(
            AIClientClassifier.retryDelaySeconds(
                for: AppError.rateLimited(retryAfter: 3),
                honorRetryAfter: false
            ),
            0
        )
        XCTAssertEqual(
            AIClientClassifier.retryDelaySeconds(for: AppError.timedOut),
            0
        )
    }

    func testRetriableClassification() {
        XCTAssertTrue(AIClientClassifier.isRetriableBeforeFirstDelta(AppError.rateLimited(retryAfter: 1)))
        XCTAssertTrue(AIClientClassifier.isRetriableBeforeFirstDelta(AppError.providerUnavailable))
        XCTAssertTrue(AIClientClassifier.isRetriableBeforeFirstDelta(AppError.timedOut))
        XCTAssertTrue(AIClientClassifier.isRetriableBeforeFirstDelta(AppError.networkUnavailable))
        XCTAssertFalse(AIClientClassifier.isRetriableBeforeFirstDelta(AppError.unauthorized))
        XCTAssertFalse(AIClientClassifier.isRetriableBeforeFirstDelta(AppError.budgetExhausted))
        XCTAssertFalse(AIClientClassifier.isRetriableBeforeFirstDelta(CancellationError()))
        XCTAssertFalse(AIClientClassifier.isRetriableBeforeFirstDelta(AppError.aiRequestFailed("x")))
    }

    func testRateLimitedBeforeFirstDeltaRetriesOnceThenSucceeds() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .fail(.rateLimited(retryAfter: 1)),
            .succeed(deltas: ["ok"])
        ])
        let service = makeService(primary: provider)
        var slept: [TimeInterval] = []
        service.retrySleep = { seconds in slept.append(seconds) }

        let response = try await service.complete(prompt: "retry me")
        XCTAssertEqual(response.content, "ok")
        XCTAssertEqual(response.finishReason, .stop)
        XCTAssertEqual(provider.attemptCount, 2)
        XCTAssertEqual(slept, [1])
    }

    func testFiveHundredBeforeFirstDeltaRetriesOnceThenTypedError() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .fail(.providerUnavailable),
            .fail(.providerUnavailable)
        ])
        let service = makeService(primary: provider)
        service.retrySleep = { _ in }

        do {
            _ = try await service.complete(prompt: "down")
            XCTFail("Expected providerUnavailable")
        } catch let error as AppError {
            guard case .providerUnavailable = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }
        XCTAssertEqual(provider.attemptCount, 2)
    }

    func testTimeoutBeforeFirstDeltaRetriesOnce() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .fail(.timedOut),
            .succeed(deltas: ["recovered"])
        ])
        let service = makeService(primary: provider)
        service.retrySleep = { _ in }

        let response = try await service.complete(prompt: "slow")
        XCTAssertEqual(response.content, "recovered")
        XCTAssertEqual(provider.attemptCount, 2)
    }

    func testNetworkErrorBeforeFirstDeltaRetriesOnce() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .fail(.networkUnavailable),
            .succeed(deltas: ["online"])
        ])
        let service = makeService(primary: provider)
        service.retrySleep = { _ in }

        let response = try await service.complete(prompt: "net")
        XCTAssertEqual(response.content, "online")
        XCTAssertEqual(provider.attemptCount, 2)
    }

    func testUnauthorizedDoesNotRetry() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .fail(.unauthorized),
            .succeed(deltas: ["should-not-run"])
        ])
        let service = makeService(primary: provider)
        service.retrySleep = { _ in }

        do {
            _ = try await service.complete(prompt: "auth")
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            guard case .unauthorized = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }
        XCTAssertEqual(provider.attemptCount, 1)
    }

    func testBudgetExhaustedDoesNotRetry() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .fail(.budgetExhausted),
            .succeed(deltas: ["should-not-run"])
        ])
        let service = makeService(primary: provider)
        service.retrySleep = { _ in }

        do {
            _ = try await service.complete(prompt: "budget")
            XCTFail("Expected budgetExhausted")
        } catch let error as AppError {
            guard case .budgetExhausted = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }
        XCTAssertEqual(provider.attemptCount, 1)
    }

    func testFailureAfterFirstDeltaKeepsPartialIncompleteNoRetry() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .failAfterDelta(text: "partial", error: .providerUnavailable),
            .succeed(deltas: ["switched"])
        ])
        let secondary = AttemptScriptProvider(scripts: [
            .succeed(deltas: ["secondary-should-not-run"])
        ])
        let service = makeService(primary: provider, secondary: secondary)
        service.retrySleep = { _ in }

        let response = try await service.complete(prompt: "midstream")
        XCTAssertEqual(response.content, "partial")
        XCTAssertEqual(response.finishReason, .incomplete)
        XCTAssertEqual(provider.attemptCount, 1, "Must not retry after first delta")
        XCTAssertEqual(secondary.attemptCount, 0, "Must not silent-switch models")
    }

    func testCancellationNeverRetriesOrFallsBack() async throws {
        let primary = CancellingProvider()
        let secondary = AttemptScriptProvider(scripts: [
            .succeed(deltas: ["fallback-forbidden"])
        ])
        let service = makeService(primary: primary, secondary: secondary)
        service.retrySleep = { _ in }

        do {
            _ = try await service.complete(prompt: "cancel")
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(primary.attemptCount, 1)
        XCTAssertEqual(secondary.attemptCount, 0)
    }

    func testFakeStreamingProviderMidStreamViaServiceIsIncomplete() async throws {
        let fake = FakeStreamingProvider(
            events: [
                .meta(route: "fake", model: "fake-model", trainsOnPrompts: false),
                .delta("hello"),
                .delta(" world"),
                .done(usage: nil)
            ],
            failureIndex: 2,
            failureError: .timedOut
        )
        let service = makeService(primary: fake)
        service.retrySleep = { _ in }

        let response = try await service.complete(prompt: "fake mid")
        XCTAssertEqual(response.content, "hello")
        XCTAssertEqual(response.finishReason, .incomplete)
    }

    func testAtMostOneRetryEvenWhenAlwaysFailing() async throws {
        let provider = AttemptScriptProvider(scripts: [
            .fail(.rateLimited(retryAfter: 0)),
            .fail(.rateLimited(retryAfter: 0)),
            .fail(.rateLimited(retryAfter: 0))
        ])
        let service = makeService(primary: provider)
        service.retrySleep = { _ in }

        do {
            _ = try await service.complete(prompt: "loop")
            XCTFail("Expected rateLimited")
        } catch let error as AppError {
            guard case .rateLimited = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }
        XCTAssertEqual(provider.attemptCount, 2)
    }

    // MARK: - Helpers

    private func makeService(
        primary: AIProvider,
        secondary: AIProvider? = nil
    ) -> AIService {
        let flags = FeatureFlags()
        flags.set("aiServiceEnabled", enabled: true)
        return AIService(
            primary: primary,
            secondary: secondary,
            eventBus: EventBus(),
            logger: LoggerService(),
            featureFlags: flags
        )
    }
}

// MARK: - Scripted attempt provider

private final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return value
    }
    func increment() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }
}

private struct AttemptScriptProvider: AIProvider {
    enum Script {
        case succeed(deltas: [String])
        case fail(AppError)
        case failAfterDelta(text: String, error: AppError)
    }

    let id = "attempt-script"
    let displayName = "Attempt Script"
    let isAvailable = true
    let scripts: [Script]
    private let counter: AttemptCounter

    var attemptCount: Int { counter.count }

    init(scripts: [Script]) {
        self.scripts = scripts
        self.counter = AttemptCounter()
    }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        var content = ""
        var usage: AIResponse.Usage?
        for try await event in stream(request) {
            switch event {
            case .meta:
                break
            case .delta(let fragment):
                content += fragment
            case .done(let doneUsage):
                usage = doneUsage
            }
        }
        return AIResponse(requestID: request.id, content: content, finishReason: .stop, usage: usage)
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        _ = request
        let index = counter.increment() - 1
        let script: Script
        if index < scripts.count {
            script = scripts[index]
        } else if let last = scripts.last {
            script = last
        } else {
            script = .fail(.aiRequestFailed("empty script"))
        }

        return AsyncThrowingStream { continuation in
            switch script {
            case .succeed(let deltas):
                continuation.yield(.meta(route: id, model: "script", trainsOnPrompts: false))
                for delta in deltas {
                    continuation.yield(.delta(delta))
                }
                continuation.yield(.done(usage: AIResponse.Usage(promptTokens: 1, completionTokens: 1)))
                continuation.finish()
            case .fail(let error):
                continuation.finish(throwing: error)
            case .failAfterDelta(let text, let error):
                continuation.yield(.meta(route: id, model: "script", trainsOnPrompts: false))
                continuation.yield(.delta(text))
                continuation.finish(throwing: error)
            }
        }
    }
}

private struct CancellingProvider: AIProvider {
    let id = "cancelling"
    let displayName = "Cancelling"
    let isAvailable = true
    private let counter = AttemptCounter()
    var attemptCount: Int { counter.count }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        _ = counter.increment()
        throw CancellationError()
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        _ = request
        let counter = self.counter
        return AsyncThrowingStream { continuation in
            _ = counter.increment()
            continuation.finish(throwing: CancellationError())
        }
    }
}
