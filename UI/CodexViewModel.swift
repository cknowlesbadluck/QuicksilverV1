import Foundation
import Observation
import Core
import ServicesAI

@MainActor
@Observable
final class CodexViewModel {
    var grokKeyDraft: String = ""
    var geminiKeyDraft: String = ""
    var gatewayURLDraft: String = ""
    var gatewayTokenDraft: String = ""
    private(set) var hasGrokKey: Bool = false
    private(set) var hasGeminiKey: Bool = false
    private(set) var hasGatewayBinding: Bool = false
    private(set) var gatewayURLDisplay: String = ""
    private(set) var providerName: String = ""
    private(set) var fallbackProviderName: String?
    private(set) var aiEnabled: Bool = false
    private(set) var statusMessage: String?
    private(set) var statusIsError: Bool = false
    private(set) var isTestingGateway: Bool = false
    /// Read-only active answer route from `RoutingConfigStore` (M3-T4).
    private(set) var activeRouteLabel: String = "cloud / main"
    /// Read-only display model for the active answer route.
    private(set) var activeModelLabel: String = "Gemini Flash"

    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        refresh()
    }

    func refresh() {
        hasGrokKey = container.aiService.hasGrokKey
        hasGeminiKey = container.aiService.hasGeminiKey
        hasGatewayBinding = container.aiService.hasGatewayBinding
        gatewayURLDisplay = container.aiService.gatewayBaseURLDisplay ?? ""
        providerName = container.aiService.currentProviderName
        fallbackProviderName = container.aiService.fallbackProviderName
        aiEnabled = container.featureFlags.isEnabled("aiServiceEnabled")
        let display = container.routingConfigStore.loadValidated().answerDisplay()
        activeRouteLabel = display.route
        activeModelLabel = display.model
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

    func bindGateway() {
        let url = gatewayURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = gatewayTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = container.aiService.configureGateway(baseURL: url, deviceToken: token) {
            statusMessage = error.userMessage
            statusIsError = true
            return
        }
        gatewayTokenDraft = ""
        // Keep URL draft filled so the operator can re-test; display comes from Keychain.
        gatewayURLDraft = url
        finishSuccessfulBind(savedMessage: "Gateway bound. Intelligence can use the Mercury Gateway.")
        Task { await refreshRoutingAfterBind(url: url, token: token) }
    }

    func unbindGateway() {
        container.aiService.clearGateway()
        gatewayURLDraft = ""
        gatewayTokenDraft = ""
        refresh()
        statusMessage = "Gateway unbound."
        statusIsError = false
    }

    func testGatewayConnection() async {
        isTestingGateway = true
        defer { isTestingGateway = false }
        let draft = gatewayURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = draft.isEmpty ? nil : draft
        switch await container.aiService.testGatewayHealth(baseURL: baseURL) {
        case .success:
            statusMessage = "Gateway reachable — Mercury health OK."
            statusIsError = false
            refresh()
        case .failure(let error):
            statusMessage = error.userMessage
            statusIsError = true
        }
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
        // setAIEnabled overwrites status; restore the bind-specific message.
        statusMessage = savedMessage
        statusIsError = false
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
        // Gateway rebuilds from Keychain inside configure* / rebuildProviders when present.
        container.aiService.rebuildProviders()
        refresh()
        statusMessage = "AI Service enabled."
        statusIsError = false
    }

    private func refreshRoutingAfterBind(url: String, token: String) async {
        guard let endpoint = try? GatewayEndpoint(raw: url) else { return }
        _ = await container.routingConfigStore.refresh(from: endpoint, deviceToken: token)
        refresh()
    }
}
