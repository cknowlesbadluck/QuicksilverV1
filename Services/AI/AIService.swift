import Foundation
import Observation
import Core

@MainActor
@Observable
public final class AIService {
    public private(set) var isProcessing = false
    public private(set) var lastResponse: AIResponse?

    /// `nil` means intelligence is unbound: no real provider has a key. Requests throw
    /// `AppError.apiKeyMissing`; no mock text is ever substituted (M1-T3).
    private var primaryProvider: AIProvider?
    private var secondaryProvider: AIProvider?
    private let eventBus: EventBus
    let logger: LoggerService
    private let featureFlags: FeatureFlags
    private let routingConfigStore: RoutingConfigStore?

    /// Injected sleep for M3-T5 retry backoff (tests replace with a no-op).
    var retrySleep: @Sendable (TimeInterval) async throws -> Void = { seconds in
        guard seconds > 0 else { return }
        try await Task.sleep(for: .seconds(seconds))
    }

    /// Override for tests. When nil, reads `retry` from `routingConfigStore` (bundled default: 1).
    var retryPolicyOverride: AIStreamExecutor.RetryPolicy?

    /// Injectable `GET /v1/health` for Codex test-connection (AppTests stub this).
    public typealias GatewayHealthFetcher = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    var gatewayHealthFetcher: GatewayHealthFetcher = { request in
        try await URLSession.shared.data(for: request)
    }

    public static let grokAPIKeyKeychainAccount = "xai.apiKey"
    public static let geminiAPIKeyKeychainAccount = "google.gemini.apiKey"

    public convenience init(
        provider: AIProvider? = nil,
        eventBus: EventBus,
        logger: LoggerService,
        featureFlags: FeatureFlags,
        routingConfigStore: RoutingConfigStore? = nil
    ) {
        let configured: (primary: AIProvider?, secondary: AIProvider?)
        if let provider {
            configured = (provider, nil)
        } else {
            configured = Self.makeConfiguredProviders()
        }
        self.init(
            primary: configured.primary,
            secondary: configured.secondary,
            eventBus: eventBus,
            logger: logger,
            featureFlags: featureFlags,
            routingConfigStore: routingConfigStore
        )
    }

    /// Explicit routing (tests). `primary == nil` is the unbound state; the Keychain is not read.
    init(
        primary: AIProvider?,
        secondary: AIProvider?,
        eventBus: EventBus,
        logger: LoggerService,
        featureFlags: FeatureFlags,
        routingConfigStore: RoutingConfigStore? = nil
    ) {
        self.eventBus = eventBus
        self.logger = logger
        self.featureFlags = featureFlags
        self.routingConfigStore = routingConfigStore
        self.primaryProvider = primary
        self.secondaryProvider = secondary
    }

    private static func makeConfiguredProviders() -> (primary: AIProvider?, secondary: AIProvider?) {
        // Gateway bind (M3-T6) wins when URL + device token are present.
        if let gateway = makeGatewayProvider() {
            return (gateway, nil)
        }
        let grokKey = KeychainStore.string(forKey: grokAPIKeyKeychainAccount)
        let geminiKey = KeychainStore.string(forKey: geminiAPIKeyKeychainAccount)
        let grok = grokKey.flatMap { $0.isEmpty ? nil : GrokAIProvider.make(apiKey: $0) }
        let gemini = geminiKey.flatMap { $0.isEmpty ? nil : GeminiAIProvider.make(apiKey: $0) }

        if let grok {
            return (grok, gemini)
        }
        if let gemini {
            return (gemini, nil)
        }
        return (nil, nil)
    }

    public func configureGrokAPIKey(_ key: String?) -> Bool {
        let normalized = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, !normalized.isEmpty {
            guard KeychainStore.set(normalized, forKey: Self.grokAPIKeyKeychainAccount) else {
                logger.error("Keychain write failed for Grok API key", category: logger.ai)
                return false
            }
        } else {
            KeychainStore.delete(forKey: Self.grokAPIKeyKeychainAccount)
        }
        rebuildProviders()
        return true
    }

    public func configureGeminiAPIKey(_ key: String?) -> Bool {
        let normalized = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, !normalized.isEmpty {
            guard KeychainStore.set(normalized, forKey: Self.geminiAPIKeyKeychainAccount) else {
                logger.error("Keychain write failed for Gemini API key", category: logger.ai)
                return false
            }
        } else {
            KeychainStore.delete(forKey: Self.geminiAPIKeyKeychainAccount)
        }
        rebuildProviders()
        return true
    }

    func rebuildProviders() {
        let configured = Self.makeConfiguredProviders()
        primaryProvider = configured.primary
        secondaryProvider = configured.secondary
        logger.info(
            "AI routing rebuilt: primary=\(currentProviderName), "
            + "fallback=\(secondaryProvider?.displayName ?? "none")",
            category: logger.ai
        )
    }

    public func setProvider(_ newProvider: AIProvider) {
        primaryProvider = newProvider
        secondaryProvider = nil
        logger.info("AI provider switched to \(newProvider.displayName)", category: logger.ai)
    }

    public static let unboundProviderID = "unbound"
    public static let unboundProviderName = "Unbound"

    /// True when a real provider is bound. False means Ask/Brain requests return the unbound state.
    public var isBound: Bool { primaryProvider != nil }
    public var currentProviderID: String { primaryProvider?.id ?? Self.unboundProviderID }
    public var currentProviderName: String { primaryProvider?.displayName ?? Self.unboundProviderName }
    public var fallbackProviderName: String? { secondaryProvider?.displayName }
    public var hasGrokKey: Bool {
        !(KeychainStore.string(forKey: Self.grokAPIKeyKeychainAccount)?.isEmpty ?? true)
    }
    public var hasGeminiKey: Bool {
        !(KeychainStore.string(forKey: Self.geminiAPIKeyKeychainAccount)?.isEmpty ?? true)
    }

    @discardableResult
    public func configureAPIKey(_ key: String?) -> Bool {
        configureGrokAPIKey(key)
    }

    public func clearAllAPIKeys() {
        KeychainStore.delete(forKey: Self.grokAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: Self.geminiAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: Self.gatewayBaseURLKeychainAccount)
        KeychainStore.delete(forKey: GatewayAIProvider.deviceTokenKeychainAccount)
        primaryProvider = nil
        secondaryProvider = nil
        logger.info("AI routing cleared: intelligence unbound", category: logger.ai)
    }

    @discardableResult
    public func complete(
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 1024
    ) async throws -> AIResponse {
        try await execute(
            prompt: prompt,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    /// Throws `.apiKeyMissing` / `.intelligenceDisabled` when a request would not hit the network.
    /// Used by MercuryBrain offline fast-fail so unbound/disabled guidance wins over airplane mode.
    public func ensureReadyForNetworkRequest() throws {
        guard primaryProvider != nil else {
            logger.info("AI request refused: intelligence unbound", category: logger.ai)
            throw AppError.apiKeyMissing
        }
        guard featureFlags.isEnabled("aiServiceEnabled") else {
            logger.info("AI request refused: intelligence disabled in the Codex", category: logger.ai)
            throw AppError.intelligenceDisabled
        }
    }

    private func execute(
        prompt: String,
        systemPrompt: String?,
        temperature: Double,
        maxTokens: Int
    ) async throws -> AIResponse {
        try ensureReadyForNetworkRequest()
        guard let provider = primaryProvider else {
            // Unreachable after ensureReadyForNetworkRequest; keeps type narrowing.
            throw AppError.apiKeyMissing
        }

        let request = AIRequest(
            prompt: prompt,
            systemPrompt: systemPrompt,
            temperature: temperature,
            maxTokens: maxTokens
        )
        isProcessing = true
        await eventBus.publish(.aiRequestStarted(requestID: request.id.uuidString))
        logger.debug("AI request started: \(request.id)", category: logger.ai)
        defer { isProcessing = false }

        do {
            let raw = try await performProviderRequest(request, primary: provider)
            switch ResponseValidator.validate(raw, preserveIncomplete: true) {
            case .accept(let response):
                lastResponse = response
                await eventBus.publish(.aiRequestCompleted(requestID: request.id.uuidString))
                if response.finishReason == .incomplete {
                    logger.info("AI request incomplete (partial kept): \(response.id)", category: logger.ai)
                } else {
                    logger.info("AI request completed: \(response.id)", category: logger.ai)
                }
                return response
            case .reject(let reason):
                logger.error("AI response rejected: \(reason)", category: logger.ai)
                throw AppError.aiRequestFailed(reason)
            }
        } catch {
            if AIClientClassifier.isCancellation(error) {
                throw CancellationError()
            }
            logger.error("AI request failed: \(error.localizedDescription)", category: logger.ai)
            throw error
        }
    }

    private func performProviderRequest(_ request: AIRequest, primary: AIProvider) async throws -> AIResponse {
        do {
            return try await AIStreamExecutor.collect(
                request: request,
                provider: primary,
                policy: effectiveRetryPolicy(),
                sleep: retrySleep
            )
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
            return try await AIStreamExecutor.collect(
                request: request,
                provider: fallback,
                policy: effectiveRetryPolicy(),
                sleep: retrySleep
            )
        }
    }

    private func effectiveRetryPolicy() -> AIStreamExecutor.RetryPolicy {
        if let retryPolicyOverride { return retryPolicyOverride }
        let retry = routingConfigStore?.loadValidated().retry
            ?? AIRoutingConfig.bundledDefault.retry
        return AIStreamExecutor.RetryPolicy(
            maxRetries: retry.maxAttempts,
            honorRetryAfter: retry.honorRetryAfter
        )
    }

    private static func isClassifiedClientError(_ error: Error) -> Bool {
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
