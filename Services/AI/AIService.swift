import Foundation
import Observation
import Core

@MainActor
@Observable
public final class AIService {
    public private(set) var isProcessing = false
    public private(set) var lastResponse: AIResponse?
    /// Origin of the most recent accepted reply; nil until one succeeds or after a failure.
    public private(set) var lastAnswerProvenance: AnswerProvenance?

    /// `nil` means intelligence is unbound: no real provider has a key. Requests throw
    /// `AppError.apiKeyMissing`; no mock text is ever substituted (M1-T3).
    var primaryProvider: AIProvider?
    var secondaryProvider: AIProvider?
    /// True only when the last rebuild left routing unbound because the Keychain was locked.
    /// An explicit clear resets it, so `rehydrateProvidersIfNeeded()` never undoes a user's removal.
    var builtWhileLocked = false
    /// M3.5-T3: tried before any cloud route when available. `nil` in tests that inject a provider.
    public var onDeviceProvider: OnDeviceAIProvider?
    private let eventBus: EventBus
    let logger: LoggerService
    let featureFlags: FeatureFlags
    let routingConfigStore: RoutingConfigStore?

    /// Injected sleep for M3-T5 retry backoff (tests replace with a no-op).
    var retrySleep: @Sendable (TimeInterval) async throws -> Void = { seconds in
        guard seconds > 0 else { return }
        try await Task.sleep(for: .seconds(seconds))
    }

    /// Override for tests. When nil, reads `retry` from `routingConfigStore` (bundled default: 1).
    var retryPolicyOverride: AIStreamExecutor.RetryPolicy?

    /// Injectable `GET /v1/health` for Codex test-connection (AppTests stub this).
    public typealias GatewayHealthFetcher = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    public var gatewayHealthFetcher: GatewayHealthFetcher = { request in
        try await GatewayStreamTransport.secureSession.data(for: request)
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
        self.init(
            primary: provider,
            secondary: nil,
            eventBus: eventBus,
            logger: logger,
            featureFlags: featureFlags,
            routingConfigStore: routingConfigStore
        )
        // When no injected provider, rebuild from Keychain (gateway / Gemini / Grok)
        // and put the system on-device model first (M3.5-T3).
        if provider == nil {
            onDeviceProvider = OnDeviceAIProvider(model: SystemOnDeviceModel.make())
            rebuildProviders()
        }
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

    private func makeConfiguredProviders() -> (primary: AIProvider?, secondary: AIProvider?) {
        // Gateway bind (M3-T6) wins when URL + device token are present.
        if let gateway = makeGatewayProvider() {
            return (gateway, nil)
        }
        let grokKey = KeychainStore.string(forKey: Self.grokAPIKeyKeychainAccount)
        let geminiKey = KeychainStore.string(forKey: Self.geminiAPIKeyKeychainAccount)
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
        let configured = makeConfiguredProviders()
        primaryProvider = configured.primary
        secondaryProvider = configured.secondary
        builtWhileLocked = primaryProvider == nil && credentialsLocked
        logger.info(
            "AI routing rebuilt: primary=\(currentProviderName), "
            + "fallback=\(secondaryProvider?.displayName ?? "none")",
            category: logger.ai
        )
    }

    public static let unboundProviderID = "unbound"
    public static let unboundProviderName = "Unbound"

    /// True when a real provider is bound. False means Ask/Brain requests return the unbound state.
    public var isBound: Bool { primaryProvider != nil || canAnswerOnDevice }
    public var fallbackProviderName: String? { secondaryProvider?.displayName }
    public var hasGrokKey: Bool {
        !(KeychainStore.string(forKey: Self.grokAPIKeyKeychainAccount)?.isEmpty ?? true)
    }
    public var hasGeminiKey: Bool {
        !(KeychainStore.string(forKey: Self.geminiAPIKeyKeychainAccount)?.isEmpty ?? true)
    }

    /// Fail-closed: unbound / unknown providers are treated as training-on-prompts.
    public var primaryTrainsOnPrompts: Bool {
        primaryProvider?.trainsOnPrompts ?? true
    }

    @discardableResult
    public func complete(
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 1024,
        history: [Message] = []
    ) async throws -> AIResponse {
        try await complete(
            AIRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                history: history,
                temperature: temperature,
                maxTokens: maxTokens
            )
        )
    }

    @discardableResult
    public func complete(_ request: AIRequest) async throws -> AIResponse {
        try await execute(request)
    }

    private func execute(_ request: AIRequest) async throws -> AIResponse {
        lastAnswerProvenance = nil
        try ensureReadyForNetworkRequest()
        isProcessing = true
        await eventBus.publish(.aiRequestStarted(requestID: request.id.uuidString))
        logger.debug("AI request started: \(request.id)", category: logger.ai)
        defer { isProcessing = false }

        do {
            let raw: AIResponse
            let provenance: AnswerProvenance
            var trains = false
            if let local = try await answerOnDeviceFirst(request) {
                raw = local
                provenance = .onDevice
            } else if request.metadata[Self.offlineKey] == "1" {
                throw AppError.networkUnavailable
            } else if let provider = primaryProvider {
                let answered = try await performProviderRequest(request, primary: provider)
                raw = answered.response
                provenance = AnswerProvenance(origin: .cloud, providerName: answered.provider.displayName)
                trains = answered.provider.trainsOnPrompts
            } else {
                throw AppError.apiKeyMissing
            }
            switch ResponseValidator.validate(raw, preserveIncomplete: true) {
            case .accept(let response):
                lastResponse = response
                lastAnswerProvenance = provenance
                recordRoute(provenance, trainsOnPrompts: trains)
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
            recordRoute(failure: error)
            throw Self.typedSurface(error)
        }
    }
}
