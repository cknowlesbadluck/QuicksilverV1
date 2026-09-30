import Foundation
import Observation
import Core
import ServicesAI

@MainActor
@Observable
final class CodexViewModel {
    var grokKeyDraft: String = ""
    var geminiKeyDraft: String = ""
    private(set) var hasGrokKey: Bool = false
    private(set) var hasGeminiKey: Bool = false
    private(set) var providerName: String = ""
    private(set) var fallbackProviderName: String?
    private(set) var aiEnabled: Bool = false
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
        finishSuccessfulBind(savedMessage: "Grok key saved to Keychain.")
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
        finishSuccessfulBind(savedMessage: "Gemini key saved to Keychain.")
    }

    /// The first successful bind wakes intelligence. Later binds leave the flag alone.
    private func finishSuccessfulBind(savedMessage: String) {
        if container.featureFlags.isEnabled("aiServiceEnabled") {
            statusMessage = savedMessage
            statusIsError = false
            refresh()
            return
        }
        setAIEnabled(true)
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
}
