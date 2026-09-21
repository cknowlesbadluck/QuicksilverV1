import Foundation
import Observation
import Core
import ServicesAI

@MainActor
@Observable
final class SettingsViewModel {
    var apiKeyDraft: String = ""
    var hasStoredKey: Bool = false
    var providerName: String = ""
    var aiEnabled: Bool = false
    var personaAutonomyEnabled: Bool = true
    var lastSwitchReason: String?
    var statusMessage: String?
    var statusIsError: Bool = false

    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        refresh()
    }

    func refresh() {
        let key = KeychainStore.string(forKey: AIService.apiKeyKeychainAccount)
        hasStoredKey = !(key?.isEmpty ?? true)
        providerName = container.aiService.currentProviderName
        aiEnabled = container.featureFlags.isEnabled("aiServiceEnabled")
        personaAutonomyEnabled = container.featureFlags.isEnabled("personaAutonomy")
        lastSwitchReason = container.personaManager.lastSwitchReason
    }

    func saveAPIKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Enter a non-empty key"
            statusIsError = true
            return
        }

        let saved = container.aiService.configureAPIKey(trimmed)
        guard saved else {
            statusMessage = "Could not save the key to the Keychain."
            statusIsError = true
            return
        }

        apiKeyDraft = ""
        refresh()

        if container.aiService.currentProviderID == "grok" {
            statusMessage = "Key saved. Provider: Grok"
            statusIsError = false
        } else if !aiEnabled {
            statusMessage = "Key saved to Keychain. Enable AI Service to use Grok."
            statusIsError = false
        } else {
            statusMessage = "Key saved. Provider: \(container.aiService.currentProviderName)"
            statusIsError = false
        }
    }

    func clearAPIKey() {
        container.aiService.configureAPIKey(nil)
        apiKeyDraft = ""
        refresh()
        statusMessage = "Key removed. Provider: Mock"
        statusIsError = false
    }

    func setAIEnabled(_ enabled: Bool) {
        container.featureFlags.set("aiServiceEnabled", enabled: enabled)
        if enabled {
            let key = KeychainStore.string(forKey: AIService.apiKeyKeychainAccount)
            container.aiService.configureAPIKey(key)
        } else {
            container.aiService.setProvider(MockAIProvider())
        }
        refresh()
        statusMessage = enabled ? "AI Service enabled" : "AI Service disabled (Mock only)"
        statusIsError = false
    }

    func setPersonaAutonomy(_ enabled: Bool) {
        container.featureFlags.set("personaAutonomy", enabled: enabled)
        refresh()
        statusMessage = enabled ? "Persona autonomy enabled" : "Persona autonomy disabled (manual only)"
        statusIsError = false
    }
}
