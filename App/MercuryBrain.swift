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
    private let registerPolicy = RegisterPolicy()
    private let broker = IntelligenceBroker()

    private(set) var personality = PersonalityState()
    private(set) var primaryInsight: String?
    private(set) var livingStatus: String = LivingNarration.defaultStatus
    private(set) var visualState: VisualState = .idle
    private(set) var activeAspect: Aspect = .quicksilver
    /// Aspect applied for the most recently completed successful `ask`.
    /// Captured before the provider await so overlapping MainActor asks cannot retag it.
    private(set) var lastAskAspectID: String = Aspect.quicksilver.rawValue
    /// Latched conversational register. Resets to `.playful` on a new Brain session.
    private(set) var activeRegister: Register = .playful
    private var lastAspectChangeAt: Date?
    /// Prior turns only. Current prompt is sent separately. Capped at 8 pairs.
    private var conversation: [Message] = []

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
        personality.recomputeForTurn(aspect: activeAspect)
        refreshLivingStatus()
    }

    var activePersonaID: String { activeAspect.rawValue }
    var activeConfiguration: PersonaConfiguration { PersonaConfiguration.forAspect(activeAspect) }

    /// Primary entry for natural language. All conversation should come through here.
    func ask(_ query: String) async throws -> String {
        personaManager.recordInteraction()
        try rejectAskWhileDisconnected()
        let intent = intentEngine.classify(query)
        let turnRegister = evaluatedRegister(query: query, intent: intent)
        activeRegister = turnRegister
        visualState = .thinking
        let turn = try await preparedAsk(query: query, intent: intent, turnRegister: turnRegister)
        // Capture before the provider await — another MainActor ask can change activeAspect while suspended.
        let aspectID = activeAspect.rawValue
        let reply = try await completeAsk(
            query: query,
            system: turn.system,
            config: turn.config,
            maxTokens: turn.maxTokens,
            history: turn.history
        )
        lastAskAspectID = aspectID
        return reply
    }

    /// Explicit aspect entry (diagnostics, chamber awaken, Intents).
    func switchAspect(to aspect: Aspect) async throws {
        visualState = .transitioning
        await applyAspect(aspect, reason: "explicit aspect", force: true)
        visualState = environmentalBaseline()
    }

    func remember(_ content: String) async {
        // Never store empty/whitespace-only memories (e.g. an unfilled Shortcut parameter).
        let content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let truncated = String(content.prefix(500))
        let policy = personaManager.activeMemoryPolicy
        await applyAspectForRemember(content: content)
        await storeMemoryItem(truncated: truncated, policy: policy)
        completeRememberInteraction()
    }

    /// Ranked memory snapshot for capability reads and diagnostics.
    /// Text queries drop the retention floor so a relevant low-importance note can surface.
    /// Limit stays at 4 on the ask path. No vectors, no cloud.
    func retrieveSnapshot(limit: Int = 5, text: String? = nil) -> [MemoryItem] {
        let policy = personaManager.activeMemoryPolicy
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !(trimmed ?? "").isEmpty
        let memoryQuery = MemoryQuery(
            personaScope: nil,
            minimumImportance: hasText ? nil : policy.retentionThreshold,
            text: hasText ? trimmed : nil,
            limit: limit
        )
        return memoryManager.items(matching: memoryQuery)
    }
}

// MARK: - Core Operations

extension MercuryBrain {

    func refreshLivingStatus() {
        let reading = BrainComposition.livingReading(state: nexus.state)
        if let insightTitle = reading.insightTitle {
            primaryInsight = insightTitle
        }
        livingStatus = reading.text
        if let nudge = reading.nudge {
            personality.increase(nudge.dimension, by: nudge.amount)
        }

        if visualState != .thinking
            && visualState != .speaking
            && visualState != .transitioning
            && visualState != .listening
            && visualState != .success
            && visualState != .warning {
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

        personality.recomputeForTurn(aspect: aspect)
        nexus.updatePersonaContext(aspect.rawValue)
        logger.info("Mercury Brain: aspect \u{2192} \(aspect.rawValue) [\(reason)]", category: logger.persona)

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
        refreshLivingStatus()
        visualState = .processing
        stabilizeVisualStateAfterSuccess()
    }

    private func evaluateBrokerDecision(intent: Intent, tokens: Int) throws -> ResourcePlan {
        let decision = BrainComposition.brokerDecision(broker, intent: intent, aspect: activeAspect, tokens: tokens)
        return try enforceBrokerDecision(decision)
    }

    /// Applies a broker decision. Internal so AppTests can force `.deny`
    /// (the production broker degrades over-budget turns and never denies).
    func enforceBrokerDecision(_ decision: IntelligenceBroker.Decision) throws -> ResourcePlan {
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


    /// M3-T7: skip the gateway while disconnected. On-device route is M3.5-T3.
    private func rejectAskWhileDisconnected() throws {
        guard nexus.state.networkStatus == "disconnected" else { return }
        try aiService.ensureReadyForNetworkRequest()
        refreshLivingStatus()
        throw AppError.networkUnavailable
    }

    /// Register is evaluated before `.thinking` so a critical Nexus signal stays visible.
    private func evaluatedRegister(query: String, intent: Intent) -> Register {
        let nexusCritical = nexus.state.recentInsights.first?.severity == .critical
            || nexus.state.recentEvents.first?.severity == .critical
        return registerPolicy.evaluate(
            text: query,
            visualState: visualState,
            intent: intent,
            previous: activeRegister,
            thermalState: nexus.state.thermalState,
            nexusSeverityCritical: nexusCritical
        )
    }

    private struct PreparedAsk {
        let system: String
        let config: PersonaConfiguration
        let maxTokens: Int
        let history: [Message]
    }

    /// Aspect, prompt, history budget, and broker cap for one ask. History is prior turns only.
    private func preparedAsk(query: String, intent: Intent, turnRegister: Register) async throws -> PreparedAsk {
        let environment = AspectPolicy.Environment(
            isLowPower: nexus.state.lowPowerMode,
            thermalState: nexus.state.thermalState
        )
        let turnAspect = aspectPolicy.aspectForTurn(intent: intent, environment: environment)
        await applyAspect(turnAspect, reason: "turn intent \(intent.kind.rawValue)")
        let config = PersonaConfiguration.forAspect(activeAspect)
        personality.recomputeForTurn(aspect: activeAspect)
        personality.noteInteraction()
        if turnRegister == .plain {
            personality.enterPlainRegister()
        }
        let system = buildSystemPrompt(
            for: config,
            memory: retrieveRelevantMemory(matching: query),
            register: turnRegister
        )
        let history = BrainComposition.recentHistory(conversation)
        let estimatedTokens = BrainComposition.estimateContextTokens(
            systemHint: system,
            memory: [],
            query: query,
            history: history
        )
        let effectivePlan = try evaluateBrokerDecision(intent: intent, tokens: estimatedTokens)
        return PreparedAsk(
            system: system,
            config: config,
            maxTokens: min(config.maxTokensHint, effectivePlan.maxOutputTokens),
            history: history
        )
    }

    private func completeAsk(
        query: String,
        system: String,
        config: PersonaConfiguration,
        maxTokens: Int,
        history: [Message]
    ) async throws -> String {
        do {
            let response = try await aiService.complete(
                prompt: query,
                systemPrompt: system,
                temperature: config.preferredTemperature,
                maxTokens: maxTokens,
                history: history
            )
            recordTurn(user: query, assistant: response.content)
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

    private func retrieveRelevantMemory(matching text: String? = nil) -> [MemoryItem] {
        retrieveSnapshot(limit: 4, text: text)
    }

    /// Keep the model-visible turn, not the personality-colored UI string.
    private func recordTurn(user: String, assistant: String) {
        conversation.append(Message(role: .user, content: user))
        conversation.append(Message(role: .assistant, content: assistant))
        conversation = BrainComposition.recentHistory(conversation)
    }

    private func buildSystemPrompt(
        for config: PersonaConfiguration,
        memory: [MemoryItem],
        register: Register
    ) -> String {
        BrainComposition.systemPrompt(
            base: config.systemPrompt,
            bias: personality.promptBias(register: register),
            memory: memory,
            state: nexus.state,
            aspect: activeAspect,
            plainMode: register == .plain
        )
    }
}

// MARK: - IntelligenceSurface

extension MercuryBrain: IntelligenceSurface {

    /// Memory snapshot for Intents / automation (alias of retrieveSnapshot).
    func snapshot(limit: Int) -> [MemoryItem] {
        retrieveSnapshot(limit: limit)
    }

    /// Aspect identity plus Nexus full diagnostic — Intents call only this.
    func statusReport() throws -> String {
        let aspect = "\(activeAspect.diagnosticLabel) (\(activeAspect.rawValue))"
        let diagnostic = try nexus.bridge.triggerDiagnostic(named: "full")
        return "\(aspect) | \(diagnostic)"
    }
}
