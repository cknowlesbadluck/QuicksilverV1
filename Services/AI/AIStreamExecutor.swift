import Foundation
import Core

/// Runs one provider stream with M3-T5 client retry / incomplete semantics.
///
/// - Cancellation never retries or falls back.
/// - Retriable failures before the first delta: at most one retry (honor `retryAfter` ≤ 5 s).
/// - Failure after the first delta: return partial text with `finishReason == .incomplete`
///   (no silent model switch — caller must not swap providers).
/// - On-device fallback after exhausted retries is M3.5-T3; until then the typed error surfaces.
enum AIStreamExecutor {
    struct RetryPolicy: Sendable {
        /// Number of retries after the first attempt (0 or 1 per M3-T5).
        var maxRetries: Int = 1
        var honorRetryAfter: Bool = true
    }

    typealias SleepHandler = @Sendable (TimeInterval) async throws -> Void

    static func collect(
        request: AIRequest,
        provider: AIProvider,
        policy: RetryPolicy = RetryPolicy(),
        sleep: SleepHandler = defaultSleep
    ) async throws -> AIResponse {
        let maxTries = 1 + max(0, policy.maxRetries)
        var attempt = 0
        while attempt < maxTries {
            attempt += 1
            try Task.checkCancellation()
            let outcome = await runAttempt(request: request, provider: provider)
            switch outcome {
            case .success(let response):
                return response
            case .incomplete(let response):
                // Partial kept; do not retry or switch models.
                return response
            case .cancelled:
                throw CancellationError()
            case .failed(let error, let sawDelta):
                if AIClientClassifier.isCancellation(error) {
                    throw CancellationError()
                }
                if sawDelta {
                    return AIResponse(
                        requestID: request.id,
                        content: "",
                        finishReason: .incomplete
                    )
                }
                let canRetry = attempt < maxTries
                    && AIClientClassifier.isRetriableBeforeFirstDelta(error)
                guard canRetry else {
                    // M3.5-T3: after retries, prefer on-device when available.
                    throw error
                }
                let delay = AIClientClassifier.retryDelaySeconds(
                    for: error,
                    honorRetryAfter: policy.honorRetryAfter
                )
                if delay > 0 {
                    try await sleep(delay)
                }
                try Task.checkCancellation()
            }
        }
        throw AppError.aiRequestFailed("stream failed")
    }

    // MARK: - Attempt

    private enum AttemptOutcome {
        case success(AIResponse)
        case incomplete(AIResponse)
        case cancelled
        case failed(Error, sawDelta: Bool)
    }

    private struct StreamAccumulation {
        var content = ""
        var usage: AIResponse.Usage?
        var finishReason: AIResponse.FinishReason = .stop
        var sawDelta = false
        var sawDone = false
    }

    private static func runAttempt(
        request: AIRequest,
        provider: AIProvider
    ) async -> AttemptOutcome {
        do {
            let accumulated = try await consumeStream(request: request, provider: provider)
            return outcome(from: accumulated, requestID: request.id)
        } catch is CancellationError {
            return .cancelled
        } catch {
            if AIClientClassifier.isCancellation(error) {
                return .cancelled
            }
            // Mid-stream throw: incomplete if any delta was already consumed — handled inside consume.
            return .failed(error, sawDelta: false)
        }
    }

    private static func consumeStream(
        request: AIRequest,
        provider: AIProvider
    ) async throws -> StreamAccumulation {
        var state = StreamAccumulation()
        do {
            for try await event in provider.stream(request) {
                try Task.checkCancellation()
                apply(event, to: &state)
            }
            try Task.checkCancellation()
            return state
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if AIClientClassifier.isCancellation(error) {
                throw CancellationError()
            }
            if state.sawDelta {
                // Signal incomplete via a dedicated path: return state marked without done.
                state.sawDone = false
                state.finishReason = .incomplete
                return state
            }
            throw error
        }
    }

    private static func apply(_ event: AIStreamEvent, to state: inout StreamAccumulation) {
        switch event {
        case .meta:
            break
        case .delta(let fragment):
            state.sawDelta = true
            state.content += fragment
        case .done(let doneUsage, let doneReason):
            state.usage = doneUsage
            state.finishReason = doneReason
            state.sawDone = true
        }
    }

    private static func outcome(
        from state: StreamAccumulation,
        requestID: UUID
    ) -> AttemptOutcome {
        if state.finishReason == .incomplete || (state.sawDelta && !state.sawDone) {
            return .incomplete(
                AIResponse(
                    requestID: requestID,
                    content: state.content,
                    finishReason: .incomplete,
                    usage: state.usage
                )
            )
        }
        if !state.sawDone {
            return .failed(AppError.providerUnavailable, sawDelta: false)
        }
        return .success(
            AIResponse(
                requestID: requestID,
                content: state.content,
                finishReason: state.finishReason,
                usage: state.usage
            )
        )
    }

    private static func defaultSleep(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(for: .seconds(seconds))
    }
}
