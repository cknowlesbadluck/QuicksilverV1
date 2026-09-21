import Foundation
import Observation
import Core
import ServicesAI

@MainActor
@Observable
final class SettingsViewModel {
    var grokKeyDraft: String = ""
    var geminiKeyDraft: String = ""
    private(set) var hasGrokKey: Bool = false
    private(set) var hasGeminiKey: Bool = false
    private(set) var providerName: String = ""
    private(set) var fallbackProviderName: String?
    private(set) var aiEnabled: Bool = false
    private(set) var personaAutonomyEnabled: Bool = true
    private(set) var lastSwitchReason: String?
    private(set) var statusMessage: String?
    private(set) var statusIsError: Bool = false
    
    private let container: DependencyContainer
    
    init(container: DependencyContainer) {
        self.container = container
        refresh()
    }
    
    func refresh() {
        hasGrokKey = container.aiService.hasGrokKey
        hasGeminiKey = container.aiService.hasGeminiKey
        providerName = container.aiService.currentProviderName
        fallbackProviderName = container.aiService.fallbackProviderName
        aiEnabled = container.featureFlags.isEnabled("aiServiceEnabled")
        personaAutonomyEnabled = container.featureFlags.isEnabled("personaAutonomy")
        lastSwitchReason = container.personaManager.lastSwitchReason
    }
    
    func saveGrokKey() {
        let trimmed = grokKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Enter a non-empty Grok API key."
            statusIsError = true
            return
        }
        guard container.aiService.configureGrokAPIKey(trimmed) else {
            statusMessage = "Could not save the Grok key to the Keychain."
            statusIsError = true
            return
        }
        grokKeyDraft = ""
        statusMessage = "Grok key saved to Keychain."
        statusIsError = false
        refresh()
    }
    
    func saveGeminiKey() {
        let trimmed = geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Enter a non-empty Gemini API key."
            statusIsError = true
            return
        }
        guard container.aiService.configureGeminiAPIKey(trimmed) else {
            statusMessage = "Could not save the Gemini key to the Keychain."
            statusIsError = true
            return
        }
        geminiKeyDraft = ""
        statusMessage = "Gemini key saved to Keychain."
        statusIsError = false
        refresh()
    }
    
    func clearGrokKey() {
        _ = container.aiService.configureGrokAPIKey(nil)
        refresh()
        statusMessage = "Grok key removed."
        statusIsError = false
    }
    
    func clearGeminiKey() {
        _ = container.aiService.configureGeminiAPIKey(nil)
        refresh()
        statusMessage = "Gemini key removed."
        statusIsError = false
    }
    
    func setAIEnabled(_ enabled: Bool) {
        container.featureFlags.set("aiServiceEnabled", enabled: enabled)
        if enabled {
            let grokKey = KeychainStore.string(forKey: AIService.grokAPIKeyKeychainAccount)
            let geminiKey = KeychainStore.string(forKey: AIService.geminiAPIKeyKeychainAccount)
            _ = container.aiService.configureGrokAPIKey(grokKey)
            _ = container.aiService.configureGeminiAPIKey(geminiKey)
        } else {
            container.aiService.setProvider(MockAIProvider())
        }
        refresh()
        statusMessage = enabled ? "AI Service enabled." : "AI Service disabled (Mock only)."
        statusIsError = false
    }
    
    func setPersonaAutonomy(_ enabled: Bool) {
        container.featureFlags.set("personaAutonomy", enabled: enabled)
        refresh()
        statusMessage = enabled ? "Persona autonomy enabled." : "Persona autonomy disabled."
        statusIsError = false
    }
}
