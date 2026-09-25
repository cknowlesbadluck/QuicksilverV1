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
/// Aspect is the single entity facet. PersonaConfiguration is a projection
/// of Aspect (voice + prompts), not a parallel product.
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
    private let broker = IntelligenceBroker()

    private(set) var personality = PersonalityState()
    private(set) var primaryInsight: String?
    private(set) var livingStatus: String = "Quicksilver is present. Observing."
    private(set) var visualState: VisualState = .idle
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

        activeAspect = BrainComposition.aspect(forPersonaID: personaManager.activePersonaID)
        personality.applyPersonaBias(personaID: activeAspect.rawValue)
        refreshLivingStatus()
    }

    var activePersonaID: String { activeAspect.rawValue }
    var activeConfiguration: PersonaConfiguration { PersonaConfiguration.forAspect(activeAspect) }

    /// Primary entry for natural language. All conversation should come through here.
    func ask(_ query: String) async throws -> String {
        personaManager.recordInteraction()
        personality.noteInteraction()
        visualState = .thinking

        let intent = intentEngine.classify(query)
        let turnAspect = aspectPolicy.aspectForTurn(intent: intent)
        await applyAspect(turnAspect, reason: "turn intent \(intent.kind.rawValue)")

        personaManager.updateTaskContext(description: query)

        let config = PersonaConfiguration.forAspect(activeAspect)
        personality.adjustForAspect(activeAspect)

        let relevantMemory = retrieveRelevantMemory()
        let estimatedTokens = BrainComposition.estimateContextTokens(
            systemHint: config.systemPrompt,
            memory: relevantMemory,
            query: query
        )

        let effectivePlan = try evaluateBrokerDecision(intent: intent, tokens: estimatedTokens)
        let system = buildSystemPrompt(for: config, memory: relevantMemory)
        let maxTokens = min(config.maxTokensHint, effectivePlan.maxOutputTokens)
        return try await completeAsk(query: query, system: system, config: config, maxTokens: maxTokens)
    }

    /// Explicit aspect entry (diagnostics, chamber awaken, Intents).
    func switchPersona(to id: String) async throws {
        visualState = .transitioning
        await applyAspect(BrainComposition.aspect(forPersonaID: id), reason: "explicit switch", force: true)
        visualState = environmentalBaseline()
    }

    /// Switch by Aspect (preferred diagnostics API).
    func switchAspect(to aspect: Aspect) async throws {
        visualState = .transitioning
        await applyAspect(aspect, reason: "explicit aspect", force: true)
        visualState = environmentalBaseline()
    }

    func remember(_ content: String) async {
        let truncated = String(content.prefix(500))
        let policy = personaManager.activeMemoryPolicy
        await applyAspectForRemember(content: content)
        updateTaskContextForRemember(truncated: truncated)
        await storeMemoryItem(truncated: truncated, policy: policy)
        completeRememberInteraction()
    }

    /// Ranked memory snapshot for capability reads and diagnostics.
    func retrieveSnapshot(limit: Int = 5) -> [MemoryItem] {
        let policy = personaManager.activeMemoryPolicy
        let memoryQuery = MemoryQuery(
            personaScope: nil,
            minimumImportance: policy.retentionThreshold,
            limit: limit
        )
        return memoryManager.items(matching: memoryQuery)
    }
}

// MARK: - Core Operations

extension MercuryBrain {

    func refreshLivingStatus() {
        let reading = BrainComposition.livingReading(state: nexus.state, label: activeAspect.diagnosticLabel)
        if let insightTitle = reading.insightTitle {
            primaryInsight = insightTitle
        }
        livingStatus = reading.text
        if let nudge = reading.nudge {
            personality.increase(nudge.dimension, by: nudge.amount)
        }

        if visualState != .thinking && visualState != .speaking && visualState != .transitioning {
            visualState = environmentalBaseline()
        }
    }

    func beginListening() {
        visualState = .listening
    }

    func endListening() {
        visualState = environmentalBaseline()
    }

    private func applyAspect(_ aspect: Aspect, reason: String, force: Bool = false) async {
        if aspect == activeAspect {
            if visualState == .thinking || visualState == .idle {
                visualState = aspect.defaultVisualState
            }
            return
        }

        if !force {
            let preferred = aspectPolicy.preferredAspect(
                current: activeAspect,
                lastChangedAt: lastAspectChangeAt,
                intent: Intent(kind: .unknown),
                isLowPower: nexus.state.lowPowerMode,
                thermalState: nexus.state.thermalState,
                hasRecentMemoryHints: !retrieveRelevantMemory().isEmpty
            )
            if preferred != aspect && preferred != nil {
                if visualState == .thinking || visualState == .idle {
                    visualState = aspect.defaultVisualState
                }
                return
            }
        }

        activeAspect = aspect
        lastAspectChangeAt = Date()

        do {
            try await personaManager.switchTo(id: aspect.rawValue, reason: "aspect projection (\(reason))")
        } catch {
            logger.error("Aspect projection failed: \(error.localizedDescription)", category: logger.persona)
        }

        personality.applyPersonaBias(personaID: aspect.rawValue)
        nexus.updatePersonaContext(aspect.rawValue)
        logger.info("Mercury Brain: aspect → \(aspect.rawValue) [\(reason)]", category: logger.persona)

        if visualState == .thinking || visualState == .idle || force {
            visualState = aspect.defaultVisualState
        }
    }
}

// MARK: - Helpers

extension MercuryBrain {

    private func applyAspectForRemember(content: String) async {
        let intent = Intent(kind: .remember, rawText: content, confidence: 1.0)
        await applyAspect(aspectPolicy.aspectForTurn(intent: intent), reason: "remember")
    }

    private func updateTaskContextForRemember(truncated: String) {
        personaManager.updateTaskContext(
            description: "Capture memory: \(String(truncated.prefix(80)))",
            memoryHints: [String(truncated.prefix(120))]
        )
    }

    private func storeMemoryItem(truncated: String, policy: MemoryPolicy) async {
        await memoryManager.set(
            key: "note.brain.\(UUID().uuidString.prefix(8))",
            value: truncated,
            category: .temporary,
            metadata: ["source": "mercury-brain", "aspect": activeAspect.rawValue],
            importanceBoost: policy.writeImportanceHint,
            personaScope: nil
        )
    }

    private func completeRememberInteraction() {
        personality.noteInsight()
        visualState = .processing
        refreshLivingStatus()
        stabilizeVisualStateAfterSuccess()
    }

    private func evaluateBrokerDecision(intent: Intent, tokens: Int) throws -> ResourcePlan {
        let decision = BrainComposition.brokerDecision(broker, intent: intent, aspect: activeAspect, tokens: tokens)

        switch decision {
        case .allow(let allowedPlan):
            return allowedPlan
        case .degrade(let degradedPlan, let reason):
            logger.info("Broker degrade: \(reason)", category: logger.general)
            return degradedPlan
        case .deny(let reason):
            visualState = .warning
            refreshLivingStatus()
            throw AppError.aiRequestFailed(reason)
        }
    }

    private func completeAsk(
        query: String,
        system: String,
        config: PersonaConfiguration,
        maxTokens: Int
    ) async throws -> String {
        do {
            let response = try await aiService.complete(
                prompt: query,
                systemPrompt: system,
                temperature: config.preferredTemperature,
                maxTokens: maxTokens
            )
            visualState = .speaking
            let colored = personality.colorResponse(response.content, personaID: config.id)
            visualState = .success
            refreshLivingStatus()
            stabilizeVisualStateAfterSuccess()
            return colored
        } catch {
            // Unbound is a state, not a failure: settle to baseline and let the UI show the notice.
            visualState = AppError.unboundNotice(for: error) == nil ? .warning : environmentalBaseline()
            refreshLivingStatus()
            throw error
        }
    }

    private func environmentalBaseline() -> VisualState {
        BrainComposition.environmentalBaseline(state: nexus.state, aspect: activeAspect)
    }

    private func stabilizeVisualStateAfterSuccess() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if visualState == .success || visualState == .processing {
                visualState = environmentalBaseline()
            }
        }
    }

    private func retrieveRelevantMemory() -> [MemoryItem] {
        retrieveSnapshot(limit: 5)
    }

    private func buildSystemPrompt(for config: PersonaConfiguration, memory: [MemoryItem]) -> String {
        BrainComposition.systemPrompt(
            base: config.systemPrompt,
            bias: personality.promptBias(),
            memory: memory,
            state: nexus.state,
            aspect: activeAspect
        )
    }
}
