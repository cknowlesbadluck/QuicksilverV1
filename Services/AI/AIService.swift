import Foundation
import Observation
import Core

@MainActor
@Observable
public final class AIService {
    public private(set) var isProcessing = false
    public private(set) var lastResponse: AIResponse?
    
    private var primaryProvider: AIProvider
    private var secondaryProvider: AIProvider?
    private let eventBus: EventBus
    private let logger: LoggerService
    private let featureFlags: FeatureFlags
    private let promptBuilder = PromptBuilder()
    private let contextAssembler = ContextAssembler()
    
    public static let grokAPIKeyKeychainAccount = "xai.apiKey"
    public static let geminiAPIKeyKeychainAccount = "google.gemini.apiKey"
    
    public init(provider: AIProvider? = nil, eventBus: EventBus, logger: LoggerService, featureFlags: FeatureFlags) {
        self.eventBus = eventBus
        self.logger = logger
        self.featureFlags = featureFlags
        
        if let provider {
            self.primaryProvider = provider
            self.secondaryProvider = nil
        } else {
            let configured = Self.makeConfiguredProviders()
            self.primaryProvider = configured.primary
            self.secondaryProvider = configured.secondary
        }
    }
    
    private static func makeConfiguredProviders() -> (primary: AIProvider, secondary: AIProvider?) {
        let grokKey = KeychainStore.string(forKey: grokAPIKeyKeychainAccount)
        let geminiKey = KeychainStore.string(forKey: geminiAPIKeyKeychainAccount)
        
        let grok = grokKey.flatMap { $0.isEmpty ? nil : GrokAIProvider.make(apiKey: $0) }
        let gemini = geminiKey.flatMap { $0.isEmpty ? nil : GeminiAIProvider.make(apiKey: $0) }
        
        // Grok is intentionally the conversational default. Gemini is the automatic fallback.
        if let grok {
            return (grok, gemini)
        }
        if let gemini {
            return (gemini, nil)
        }
        return (MockAIProvider(), nil)
    }
    
    public func configureGrokAPIKey(_ key: String?) -> Bool {
        let normalized = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            KeychainStore.delete(forKey: Self.grokAPIKeyKeychainAccount)
        } else {
            guard KeychainStore.set(normalized, forKey: Self.grokAPIKeyKeychainAccount) else {
                logger.error("Keychain write failed for Grok API key", category: logger.ai)
                return false
            }
        }
        rebuildProviders()
        return true
    }
    
    public func configureGeminiAPIKey(_ key: String?) -> Bool {
        let normalized = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized, !normalized.isEmpty else {
            KeychainStore.delete(forKey: Self.geminiAPIKeyKeychainAccount)
        } else {
            guard KeychainStore.set(normalized, forKey: Self.geminiAPIKeyKeychainAccount) else {
                logger.error("Keychain write failed for Gemini API key", category: logger.ai)
                return false
            }
        }
        rebuildProviders()
        return true
    }
    
    private func rebuildProviders() {
        let configured = Self.makeConfiguredProviders()
        primaryProvider = configured.primary
        secondaryProvider = configured.secondary
        logger.info(
            "AI routing rebuilt: primary=\(primaryProvider.displayName), fallback=\(secondaryProvider?.displayName ?? "none")",
            category: logger.ai
        )
    }
    
    public func setProvider(_ newProvider: AIProvider) {
        primaryProvider = newProvider
        secondaryProvider = nil
        logger.info("AI provider switched to \(newProvider.displayName)", category: logger.ai)
    }
    
    public var currentProviderID: String { primaryProvider.id }
    public var currentProviderName: String { primaryProvider.displayName }
    public var fallbackProviderName: String? { secondaryProvider?.displayName }
    
    public var hasGrokKey: Bool {
        !(KeychainStore.string(forKey: Self.grokAPIKeyKeychainAccount)?.isEmpty ?? true)
    }
    
    public var hasGeminiKey: Bool {
        !(KeychainStore.string(forKey: Self.geminiAPIKeyKeychainAccount)?.isEmpty ?? true)
    }
    
    /// Compatibility entry point for the existing Settings surface.
    @discardableResult
    public func configureAPIKey(_ key: String?) -> Bool {
        configureGrokAPIKey(key)
    }
    
    public func clearAllAPIKeys() {
        KeychainStore.delete(forKey: Self.grokAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: Self.geminiAPIKeyKeychainAccount)
        primaryProvider = MockAIProvider()
        secondaryProvider = nil
    }
    
    public func complete(
        userMessage: String,
        personaSystemPrompt: String,
        preferredTemperature: Double = 0.7,
        maxTokensHint: Int = 1024,
        context: ContextAssembler.Input = .init()
    ) async throws -> AIResponse {
        let assembled = contextAssembler.assemble(context)
        let built = promptBuilder.build(
            personaSystemPrompt: personaSystemPrompt,
            preferredTemperature: preferredTemperature,
            maxTokensHint: maxTokensHint,
            userMessage: userMessage,
            assembledContext: assembled
        )
        return try await execute(
            prompt: built.userPrompt,
            systemPrompt: built.systemPrompt,
            temperature: built.temperature,
            maxTokens: built.maxTokens
        )
    }
    
    public func complete(prompt: String, systemPrompt: String? = nil, temperature: Double = 0.7, maxTokens: Int = 1024) async throws -> AIResponse {
        try await execute(prompt: prompt, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens)
    }
    
    private func execute(prompt: String, systemPrompt: String?, temperature: Double, maxTokens: Int) async throws -> AIResponse {
        guard featureFlags.isEnabled("aiServiceEnabled") || primaryProvider.id == "mock" else {
            throw AppError.unsupportedFeature("AI service is currently disabled by feature flag")
        }
        
        let request = AIRequest(prompt: prompt, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens)
        isProcessing = true
        await eventBus.publish(.aiRequestStarted(requestID: request.id.uuidString))
        logger.debug("AI request started: \(request.id)", category: logger.ai)
        defer { isProcessing = false }
        
        do {
            let raw: AIResponse
            do {
                raw = try await primaryProvider.complete(request)
            } catch {
                guard let fallback = secondaryProvider, fallback.isAvailable else {
                    throw error
                }
                logger.info(
                    "Primary AI provider failed; attempting free-tier fallback: \(fallback.displayName)",
                    category: logger.ai
                )
                raw = try await fallback.complete(request)
            }
            
            switch ResponseValidator.validate(raw) {
            case .accept(let response):
                lastResponse = response
                await eventBus.publish(.aiRequestCompleted(requestID: request.id.uuidString))
                logger.info("AI request completed: \(response.id)", category: logger.ai)
                return response
            case .reject(let reason):
                logger.error("AI response rejected: \(reason)", category: logger.ai)
                throw AppError.aiRequestFailed(reason)
            }
        } catch {
            logger.error("AI request failed: \(error.localizedDescription)", category: logger.ai)
            throw error
        }
    }
}
