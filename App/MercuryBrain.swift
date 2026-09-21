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
/// - Understand intent (via IntentEngine)
/// - Select aspect (via AspectPolicy)
/// - Retrieve context (memory + Nexus signals + persona state)
/// - Decide when to use tools / AI providers
/// - Plan and validate responses
/// - Influence personality behavioral state
/// - Surface insights rather than raw data
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

    private let intentEngine = IntentEngine()
    private let aspectPolicy = AspectPolicy()

    private(set) var personality = PersonalityState()
    private(set) var primaryInsight: String?
    private(set) var livingStatus: String = "Quicksilver is present. Observing."
    /// Explicit visual communication state — UI only observes.
    private(set) var visualState: VisualState = .idle
    /// Current aspect of the single entity (driven by policy).
    private(set) var activeAspect: Aspect = .quicksilver
    private var lastAspectChangeAt: Date?

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
        activeAspect = mapPersonaToAspect(personaManager.activePersonaID)
        refreshLivingStatus()
    }

    var activePersonaID: String { personaManager.activePersonaID }
    var activeConfiguration: PersonaConfiguration { personaManager.activeConfiguration }

    /// Primary entry for natural language. All conversation should come through here.
    func ask(_ query: String) async throws -> String {
        personaManager.recordInteraction()
        personality.noteInteraction()
        visualState = .thinking

        // 1. Classify with the new Core IntentEngine
        let intent = intentEngine.classify(query)

        // 2. Decide aspect for this turn (immediate, no dwell)
        let turnAspect = aspectPolicy.aspectForTurn(intent: intent)
        applyAspectIfNeeded(turnAspect, reason: "turn intent \(intent.kind.rawValue)")

        // 3. Bridge to legacy QueryIntent / TaskKind so existing PersonaDecisionPolicy still works
        let (legacyIntent, legacyKind) = bridgeToLegacy(intent)

        personaManager.updateTaskContext(
            description: query,
            kind: legacyKind,
            queryIntent: legacyIntent
        )

        personality.adjustFor(intent: legacyIntent, kind: legacyKind)

        let config = personaManager.activeConfiguration
        let relevantMemory = retrieveRelevantMemory(for: query, personaID: config.id)
        let system = buildSystemPrompt(for: config, memory: relevantMemory)

        do {
            let response = try await aiService.complete(
                prompt: query,
                systemPrompt: system,
                temperature: config.preferredTemperature,
                maxTokens: config.maxTokensHint
            )

            visualState = .speaking
            let colored = personality.colorResponse(response.content, personaID: config.id)

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
        activeAspect = mapPersonaToAspect(id)
        lastAspectChangeAt = Date()
        refreshLivingStatus()
        logger.info("Mercury Brain: persona → \(id)", category: logger.persona)
        visualState = environmentalBaseline()
    }

    func remember(_ content: String) async {
        let truncated = String(content.prefix(500))
        let personaID = personaManager.activePersonaID
        let policy = personaManager.activeMemoryPolicy

        let intent = Intent(kind: .remember, rawText: content, confidence: 1.0)
        let turnAspect = aspectPolicy.aspectForTurn(intent: intent)
        applyAspectIfNeeded(turnAspect, reason: "remember")

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

    // MARK: - Aspect application

    private func applyAspectIfNeeded(_ aspect: Aspect, reason: String) {
        guard aspect != activeAspect else {
            // Still bias visual for the turn
            if visualState == .thinking || visualState == .idle {
                visualState = aspect.defaultVisualState
            }
            return
        }

        // Autonomous change path (respects dwell inside policy for longer-lived switches)
        if let preferred = aspectPolicy.preferredAspect(
            current: activeAspect,
            lastChangedAt: lastAspectChangeAt,
            intent: Intent(kind: .unknown), // already decided for turn
            isLowPower: nexus.state.lowPowerMode,
            thermalState: nexus.state.thermalState,
            hasRecentMemoryHints: !retrieveRelevantMemory(for: "", personaID: activePersonaID).isEmpty
        ), preferred == aspect {
            activeAspect = preferred
            lastAspectChangeAt = Date()
            logger.info("Mercury Brain: aspect → \(preferred.rawValue) [\(reason)]", category: logger.persona)
        } else {
            // For the current turn we still adopt the visual language
            activeAspect = aspect
        }

        if visualState == .thinking || visualState == .idle {
            visualState = aspect.defaultVisualState
        }
    }

    private func mapPersonaToAspect(_ personaID: String) -> Aspect {
        switch personaID {
        case "forge": return .forge
        case "eternal": return .eternal
        default: return .quicksilver
        }
    }

    // MARK: - Bridge to legacy types (temporary)

    private func bridgeToLegacy(_ intent: Intent) -> (QueryIntent, TaskKind) {
        switch intent.kind {
        case .create:
            return (.preciseTechnical, .building)
        case .diagnose:
            return (.diagnostic, .debugging)
        case .observe, .retrieve:
            return (.reflective, .reflecting)
        case .remember:
            return (.reflective, .reflecting)
        case .express, .inquire:
            return (.strategic, .exploring)
        case .switchAspect, .unknown:
            return (.unknown, .unknown)
        }
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
        // Prefer aspect default when environment is calm
        return activeAspect.defaultVisualState
    }

    private func stabilizeVisualStateAfterSuccess() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if visualState == .success || visualState == .processing {
                visualState = environmentalBaseline()
            }
        }
    }

    // MARK: - Memory context assembly

    /// Retrieve a small, ranked, persona-aware set of memory items for prompt injection.
    /// Hard limit + importance floor keeps the prompt lean and private.
    private func retrieveRelevantMemory(for query: String, personaID: String) -> [MemoryItem] {
        let policy = personaManager.activeMemoryPolicy
        let memoryQuery = MemoryQuery(
            personaScope: personaID,
            minimumImportance: policy.retentionThreshold,
            limit: 5
        )
        return memoryManager.items(matching: memoryQuery)
    }

    // MARK: - Internals

    private func buildSystemPrompt(for config: PersonaConfiguration, memory: [MemoryItem]) -> String {
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

        if !memory.isEmpty {
            prompt += "\n\nRelevant memory (private, ranked by importance):\n"
            for item in memory {
                let snippet = String(item.value.prefix(180))
                prompt += "- [\(item.category.rawValue)] \(snippet)\n"
            }
        }

        let health = nexus.state.overallHealthScore
        let battery = nexus.state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "unknown"
        prompt += "\n\nDevice context (private): health \(health), battery \(battery)."
        prompt += "\nActive aspect: \(activeAspect.diagnosticLabel)."

        return prompt
    }
}
