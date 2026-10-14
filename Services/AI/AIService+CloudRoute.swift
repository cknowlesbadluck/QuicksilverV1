import Foundation
import Core

/// Cloud leg of `AIService.execute`: primary provider, legacy secondary fallback, retry policy.
extension AIService {
    /// Returns the response and the provider that actually produced it (primary or secondary).
    func performProviderRequest(
        _ request: AIRequest,
        primary: AIProvider
    ) async throws -> (response: AIResponse, provider: AIProvider) {
        do {
            let response = try await AIStreamExecutor.collect(
                request: request,
                provider: primary,
                policy: effectiveRetryPolicy(),
                sleep: retrySleep
            )
            return (response, primary)
        } catch {
            if AIClientClassifier.isCancellation(error) {
                throw CancellationError()
            }
            // Classified gateway/client errors: typed surface (on-device comes in M3.5-T3).
            // Cancellation never falls back. Incomplete partials never reach here (returned above).
            if Self.isClassifiedClientError(error) {
                throw error
            }
            // Interim Grok→Gemini secondary for legacy direct-provider failures only.
            guard let fallback = secondaryProvider, fallback.isAvailable else { throw error }
            logger.info(
                "Primary AI provider failed; attempting fallback: \(fallback.displayName)",
                category: logger.ai
            )
            let fallbackRequest = Self.requestForFallback(request, provider: fallback)
            let response = try await AIStreamExecutor.collect(
                request: fallbackRequest,
                provider: fallback,
                policy: effectiveRetryPolicy(),
                sleep: retrySleep
            )
            return (response, fallback)
        }
    }

    func effectiveRetryPolicy() -> AIStreamExecutor.RetryPolicy {
        if let retryPolicyOverride { return retryPolicyOverride }
        let retry = routingConfigStore?.loadValidated().retry
            ?? AIRoutingConfig.bundledDefault.retry
        return AIStreamExecutor.RetryPolicy(
            maxRetries: retry.maxAttempts,
            honorRetryAfter: retry.honorRetryAfter
        )
    }

    /// When falling back to a trainsOnPrompts provider, redact standard memory/device context.
    static func requestForFallback(_ request: AIRequest, provider: AIProvider) -> AIRequest {
        guard provider.trainsOnPrompts else { return request }
        return CloudContextPolicy.redactForTrainingProvider(request)
    }

    static func isClassifiedClientError(_ error: Error) -> Bool {
        guard let appError = error as? AppError else { return false }
        switch appError {
        // Keep `.networkUnavailable` out: legacy Grok→Gemini secondary must still run
        // when a direct-provider transport fails (Codex P1). Gateway has no secondary.
        case .rateLimited, .unauthorized, .providerUnavailable, .budgetExhausted, .timedOut:
            return true
        default:
            return false
        }
    }
}
