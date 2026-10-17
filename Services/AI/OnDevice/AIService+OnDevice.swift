import Foundation
import Core

/// M3.5-T3: Apple on-device first, then the bound cloud route.
/// Personal data never needs to leave: when the on-device model answers, nothing
/// is sent anywhere. Cloud is used only when on-device is unavailable or fails.
extension AIService {
    /// Request metadata key carrying the compact on-device system prompt (P-T4).
    nonisolated public static let onDeviceInstructionsKey = "onDeviceSystem"
    /// Metadata flag the Brain sets when Nexus reports no network: never fall back to cloud.
    nonisolated public static let offlineKey = "offline"
    /// Prior messages kept for the small on-device window (4 user/assistant pairs).
    nonisolated public static let onDeviceHistoryMessages = 8

    /// Why the on-device mind can or cannot answer (Codex / Diagnostics).
    public var onDeviceAvailability: OnDeviceModelAvailability {
        onDeviceProvider?.availability ?? .unsupportedOS
    }

    /// Bound route id/name; the on-device route counts when no cloud is bound.
    public var currentProviderID: String {
        primaryProvider?.id ?? (canAnswerOnDevice ? OnDeviceAIProvider.routeID : Self.unboundProviderID)
    }
    public var currentProviderName: String {
        primaryProvider?.displayName ?? (canAnswerOnDevice ? OnDeviceAIProvider.routeName : Self.unboundProviderName)
    }

    /// True when the on-device model is present and ready.
    public var canAnswerOnDevice: Bool { onDeviceProvider?.isAvailable ?? false }

    /// Route the next request will try first, for the UI.
    public var activeRouteName: String {
        if canAnswerOnDevice { return OnDeviceAIProvider.routeName }
        return currentProviderName
    }

    /// M3.5-T4: warm the on-device model when the Invocation opens. No-op when unavailable.
    public func prewarmOnDevice(instructions: String? = nil) {
        guard canAnswerOnDevice, featureFlags.isEnabled("aiServiceEnabled") else { return }
        onDeviceProvider?.prewarm(instructions: instructions)
    }

    /// Frees the warmed on-device session (memory warning, AI off). The next ask builds a new one.
    public func releaseOnDeviceResources() {
        onDeviceProvider?.discardPrewarmed()
    }

    /// Compact request for the on-device model: compact instructions when the
    /// Brain supplied them, and only the newest turns.
    public static func onDeviceRequest(from request: AIRequest) -> AIRequest {
        let instructions = request.metadata[onDeviceInstructionsKey].flatMap { $0.isEmpty ? nil : $0 }
        return AIRequest(
            id: request.id,
            prompt: request.prompt,
            systemPrompt: instructions ?? request.systemPrompt,
            history: Array((request.onDeviceHistory ?? request.history).suffix(onDeviceHistoryMessages)),
            context: [],
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            metadata: request.metadata
        )
    }

    /// Tries on-device first. Returns nil when the caller should use the cloud
    /// route (on-device unavailable, or failed with a cloud route bound).
    func answerOnDeviceFirst(_ request: AIRequest) async throws -> AIResponse? {
        guard let onDevice = onDeviceProvider, onDevice.isAvailable else { return nil }
        do {
            let response = try await collectOnDevice(request, provider: onDevice)
            logger.info("AI answered on device", category: logger.ai)
            return response
        } catch {
            if AIClientClassifier.isCancellation(error) { throw CancellationError() }
            // A safety refusal is a decision, not an outage: never re-send it to the cloud.
            if case OnDeviceModelError.guardrailViolation = error {
                throw AppError.aiRequestFailed("on-device: request declined")
            }
            if request.metadata[Self.offlineKey] == "1" {
                throw AppError.networkUnavailable
            }
            guard primaryProvider != nil else {
                logger.error("On-device failed and no cloud route is bound", category: logger.ai)
                throw AppError.aiRequestFailed("on-device: \(error.localizedDescription)")
            }
            // Privacy gate (CloudContextPolicy): personal turns never fall back to the cloud.
            guard CloudContextPolicy.allowsCloudFallback(request) else {
                logger.info("On-device failed; personal turn kept on device", category: logger.ai)
                throw AppError.keptOnDevice
            }
            // Budget spent today: don't make a gateway round trip that can only say so.
            if primaryProvider is GatewayAIProvider, cloudBudget.current()?.isExhausted == true {
                logger.info("On-device failed; cloud budget spent today", category: logger.ai)
                throw AppError.budgetExhausted
            }
            logger.info("On-device failed; falling back to \(currentProviderName)", category: logger.ai)
            return nil
        }
    }
}

extension AIService {
    /// One on-device attempt, or two when the gateway budget is near today's limit
    /// (free-budget awareness), so a transient local failure doesn't spend scarce cloud requests.
    /// Guardrail refusals and cancellation are never retried.
    func collectOnDevice(_ request: AIRequest, provider: OnDeviceAIProvider) async throws -> AIResponse {
        let attempts = cloudBudgetIsNearLimit ? 2 : 1
        var lastError: Error = OnDeviceModelError.generationFailed("no attempt")
        for _ in 0..<attempts {
            do {
                let response = try await AIStreamExecutor.collect(
                    request: Self.onDeviceRequest(from: request),
                    provider: provider,
                    policy: AIStreamExecutor.RetryPolicy(maxRetries: 0, honorRetryAfter: false),
                    sleep: retrySleep
                )
                // An empty local answer is a failure, not a reply: let the cloud try.
                guard !response.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw OnDeviceModelError.generationFailed("empty response")
                }
                return response
            } catch {
                if AIClientClassifier.isCancellation(error) { throw error }
                if case OnDeviceModelError.guardrailViolation = error { throw error }
                lastError = error
            }
        }
        throw lastError
    }

    /// True only for a gateway route whose budget reading for today is near the limit.
    var cloudBudgetIsNearLimit: Bool {
        primaryProvider is GatewayAIProvider && cloudBudget.current()?.isNearLimit == true
    }
}

extension OnDeviceAIProvider {
    public static let routeName = "Apple Intelligence (on-device)"
    public static let routeID = "on-device"
}
