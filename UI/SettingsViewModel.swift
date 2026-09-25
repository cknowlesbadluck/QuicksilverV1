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
    private(set) var personaAutonomyEnabled: Bool = false
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
        personaAutonomyEnabled = false
        lastSwitchReason = container.personaManager.lastSwitchReason
    }
    
    func saveGrokKey() {
        let trimmed = grokKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            statusMessage = "Enter a non-empty Grok API key."
            statusIsError = true
            return
        }
        if !container.aiService.configureGrokAPIKey(trimmed) {
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
        if trimmed.isEmpty {
            statusMessage = "Enter a non-empty Gemini API key."
            statusIsError = true
            return
        }
        if !container.aiService.configureGeminiAPIKey(trimmed) {
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
        if !enabled {
            // No mock fallback: Ask/Brain now return the unbound state (M1-T3).
            refresh()
            statusMessage = "Intelligence dormant. Mercury stays silent until you wake it."
            statusIsError = false
            return
        }
        let grokKey = KeychainStore.string(forKey: AIService.grokAPIKeyKeychainAccount)
        let geminiKey = KeychainStore.string(forKey: AIService.geminiAPIKeyKeychainAccount)
        _ = container.aiService.configureGrokAPIKey(grokKey)
        _ = container.aiService.configureGeminiAPIKey(geminiKey)
        refresh()
        statusMessage = "AI Service enabled."
        statusIsError = false
    }
    
    /// Compatibility shim for older callers. Aspect autonomy is Brain-owned and cannot be toggled here.
    func setPersonaAutonomy(_ enabled: Bool) {
        personaAutonomyEnabled = false
        statusMessage = "Aspect autonomy is Brain-owned and always active."
        statusIsError = false
    }
}
