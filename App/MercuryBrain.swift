import Foundation
import Observation
import Core
import Personas
import Memory
import ServicesAI
import Nexus

/// Mercury Brain — central intelligence coordinator.
///
/// Invisible Architecture: UI and Intents never select engines, providers,
/// or memory strategies. The Brain decides.
///
/// Responsibilities:
/// - Understand intent
/// - Retrieve context (memory + Nexus signals + persona state)
/// - Decide when to use tools / AI providers
/// - Plan and validate responses
/// - Influence personality behavioral state
/// - Surface insights rather than raw data
/// - Determine which chamber (Forge / Eternal / Sanctum) should awaken
/// - Own VisualState so the environment reflects cognition
@MainActor
@Observable
final class MercuryBrain {

    private let personaManager: PersonaManager
    private let memoryManager: MemoryManager
    private let aiService: AIService
    private let nexus: NexusCoordinator
    private let eventBus: EventBus
    private let logger: LoggerService

    private(set) var personality = PersonalityState()
    private(set) var primaryInsight: String?
    private(set) var livingStatus: String = "Quicksilver is present. Observing."
    private(set) var suggestedChamber: SanctumChamber = .sanctum
    /// Explicit visual communication state — UI only observes.
    private(set) var visualState: VisualState = .idle

    init(
        personaManager: PersonaManager,
        memoryManager: MemoryManager,
        aiService: AIService,
        nexus: NexusCoordinator,
        eventBus: EventBus,
        logger: LoggerService
    ) {
        self.personaManager = personaManager
        self.memoryManager = memoryManager
        self.aiService = aiService
        self.nexus = nexus
        self.eventBus = eventBus
        self.logger = logger

        personality.applyPersonaBias(personaID: personaManager.activePersonaID)
        refreshLivingStatus()
    }

    var activePersonaID: String { personaManager.activePersonaID }
    var activeConfiguration: PersonaConfiguration { personaManager.activeConfiguration }

    /// Primary entry for natural language. All conversation should come through here.
    func ask(_ query: String) async throws -> String {
        personaManager.recordInteraction()
        personality.noteInteraction()
        visualState = .thinking

        let lower = query.lowercased()
        let (intent, kind) = classify(query: lower)

        personaManager.updateTaskContext(
            description: query,
            kind: kind,
            queryIntent: intent
        )

        personality.adjustFor(intent: intent, kind: kind)
        suggestedChamber = chamberFor(intent: intent, kind: kind, personaID: activePersonaID)

        let config = personaManager.activeConfiguration
        let system = buildSystemPrompt(for: config)

        do {
            let response = try await aiService.complete(
                prompt: query,
                systemPrompt: system,
                temperature: config.preferredTemperature,
                maxTokens: config.maxTokensHint
            )

            visualState = .speaking
            let colored = personality.colorResponse(response.content, personaID: config.id)

            // Brief success stabilization, then return to environmental baseline
            visualState = .success
            refreshLivingStatus()
            stabilizeVisualStateAfterSuccess()
            return colored
        } catch {
            visualState = .warning
            refreshLivingStatus()
            throw error
        }
    }

    func switchPersona(to id: String) async throws {
        visualState = .transitioning
        try await personaManager.switchTo(id: id)
        personality.applyPersonaBias(personaID: id)
        nexus.updatePersonaContext(id)
        suggestedChamber = chamberForPersona(id)
        refreshLivingStatus()
        logger.info("Mercury Brain: persona → \(id)", category: logger.persona)
        visualState = environmentalBaseline()
    }

    func remember(_ content: String) async {
        let truncated = String(content.prefix(500))
        let personaID = personaManager.activePersonaID
        let policy = personaManager.activeMemoryPolicy

        personaManager.updateTaskContext(
            description: "Capture memory: \(String(truncated.prefix(80)))",
            kind: .reflecting,
            queryIntent: .reflective,
            memoryHints: [String(truncated.prefix(120))]
        )

        await memoryManager.set(
            key: "note.brain.\(UUID().uuidString.prefix(8))",
            value: truncated,
            category: .temporary,
            metadata: ["source": "mercury-brain", "persona": personaID],
            importanceBoost: policy.writeImportanceHint,
            personaScope: personaID
        )

        personality.noteInsight()
        visualState = .processing
        refreshLivingStatus()
        stabilizeVisualStateAfterSuccess()
    }

    func refreshLivingStatus() {
        let state = nexus.state
        let persona = personaManager.activeConfiguration.displayName

        if let insight = state.recentInsights.first {
            primaryInsight = insight.title
            livingStatus = "\(persona): \(insight.title)"
        } else if state.overallHealthScore < 50 {
            livingStatus = "\(persona) watches rising pressure. Health \(state.overallHealthScore)."
            personality.increase(.skepticism, by: 0.04)
        } else if state.lowPowerMode {
            livingStatus = "\(persona) notes low power. Conserving."
            personality.increase(.patience, by: 0.03)
        } else {
            livingStatus = "\(persona) is present. The Sanctum holds."
        }

        // Do not clobber in-flight cognitive states
        if visualState != .thinking && visualState != .speaking && visualState != .transitioning {
            visualState = environmentalBaseline()
        }
    }

    /// Call when UI begins listening (e.g. voice invocation).
    func beginListening() {
        visualState = .listening
    }

    func endListening() {
        visualState = environmentalBaseline()
    }

    // MARK: - Visual baseline from Nexus

    private func environmentalBaseline() -> VisualState {
        let state = nexus.state
        let thermal = state.thermalState.lowercased()
        if thermal.contains("serious") || thermal.contains("critical") {
            return .critical
        }
        if state.overallHealthScore < 35 {
            return .warning
        }
        if state.lowPowerMode {
            return .sleeping
        }
        if state.overallHealthScore < 55 {
            return .processing
        }
        return .idle
    }

    private func stabilizeVisualStateAfterSuccess() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if visualState == .success || visualState == .processing {
                visualState = environmentalBaseline()
            }
        }
    }

    // MARK: - Internals

    private func classify(query: String) -> (QueryIntent, TaskKind) {
        let technicalKeywords = [
            "architect", "implement", "refactor", "debug", "error", "crash",
            "fix", "structure", "precision", "swift", "xcode", "spm",
            "git", "commit", "pr ", "pull request"
        ]
        if containsAny(query, technicalKeywords) {
            return (.preciseTechnical, .building)
        }

        let reflectiveKeywords = [
            "reflect", "remember", "history", "pattern", "long-term",
            "why did", "continuity", "archive", "memory"
        ]
        if containsAny(query, reflectiveKeywords) {
            return (.reflective, .reflecting)
        }

        let creativeKeywords = [
            "idea", "brainstorm", "what if", "explore", "creative",
            "option", "strategy", "imagine"
        ]
        if containsAny(query, creativeKeywords) {
            return (.creative, .exploring)
        }

        let diagnosticKeywords = [
            "diagnose", "why is", "broken", "failing", "battery",
            "network", "health", "thermal"
        ]
        if containsAny(query, diagnosticKeywords) {
            return (.diagnostic, .debugging)
        }

        return (.strategic, .exploring)
    }

    private func chamberFor(intent: QueryIntent, kind: TaskKind, personaID: String) -> SanctumChamber {
        if personaID == "forge" || intent == .preciseTechnical || kind == .building || kind == .debugging {
            return .forge
        }
        if personaID == "eternal" || intent == .reflective || intent == .diagnostic || kind == .reflecting {
            return .eternal
        }
        return .sanctum
    }

    private func chamberForPersona(_ id: String) -> SanctumChamber {
        switch id.lowercased() {
        case "forge": return .forge
        case "eternal": return .eternal
        default: return .sanctum
        }
    }

    private func buildSystemPrompt(for config: PersonaConfiguration) -> String {
        var prompt = config.systemPrompt

        let bias = personality.promptBias()
        if !bias.isEmpty {
            prompt += "\n\nBehavioral posture (internal): \(bias)"
        }

        prompt += """


Core stance:
- Truth is more important than agreement.
- Challenge unsupported conclusions with precision.
- Critique ideas, never the person.
- Admit uncertainty when evidence is incomplete.
- Prefer the smallest verifiable next step over speculation.
- Dry, elegant wit is allowed; cruelty is not.
- Everything ultimately serves the user's long-term success.
"""

        let health = nexus.state.overallHealthScore
        let battery = nexus.state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "unknown"
        prompt += "\n\nDevice context (private): health \(health), battery \(battery)."

        return prompt
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}
