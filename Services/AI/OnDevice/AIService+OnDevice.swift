import Foundation
import Core

/// M3.5-T3: Apple on-device first, then the bound cloud route.
/// Personal data never needs to leave: when the on-device model answers, nothing
/// is sent anywhere. Cloud is used only when on-device is unavailable or fails.
extension AIService {
    /// Request metadata key carrying the compact on-device system prompt (P-T4).
    public static let onDeviceInstructionsKey = "onDeviceSystem"
    /// Prior turns kept for the small on-device context window.
    public static let onDeviceHistoryTurns = 4

    /// Why the on-device mind can or cannot answer (Codex / Diagnostics).
    public var onDeviceAvailability: OnDeviceModelAvailability {
        onDeviceProvider?.availability ?? .unsupportedOS
    }

    /// True when the on-device model is present and ready.
    public var canAnswerOnDevice: Bool { onDeviceProvider?.isAvailable ?? false }

    /// Route the next request will try first, for the UI.
    public var activeRouteName: String {
        if canAnswerOnDevice { return OnDeviceAIProvider.routeName }
        return currentProviderName
    }

    /// Compact request for the on-device model: compact instructions when the
    /// Brain supplied them, and only the newest turns.
    public static func onDeviceRequest(from request: AIRequest) -> AIRequest {
        let instructions = request.metadata[onDeviceInstructionsKey].flatMap { $0.isEmpty ? nil : $0 }
        return AIRequest(
            id: request.id,
            prompt: request.prompt,
            systemPrompt: instructions ?? request.systemPrompt,
            history: Array(request.history.suffix(onDeviceHistoryTurns)),
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
            let response = try await AIStreamExecutor.collect(
                request: Self.onDeviceRequest(from: request),
                provider: onDevice,
                policy: AIStreamExecutor.RetryPolicy(maxRetries: 0, honorRetryAfter: false),
                sleep: retrySleep
            )
            logger.info("AI answered on device", category: logger.ai)
            return response
        } catch {
            if AIClientClassifier.isCancellation(error) { throw CancellationError() }
            guard primaryProvider != nil else {
                logger.error("On-device failed and no cloud route is bound", category: logger.ai)
                throw AppError.aiRequestFailed("on-device: \(error.localizedDescription)")
            }
            logger.info("On-device failed; falling back to \(currentProviderName)", category: logger.ai)
            return nil
        }
    }
}

extension OnDeviceAIProvider {
    public static let routeName = "Apple Intelligence (on-device)"
}
