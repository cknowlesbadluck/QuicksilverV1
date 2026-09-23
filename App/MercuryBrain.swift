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

        activeAspect = mapPersonaToAspect(personaManager.activePersonaID)
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

        let effectivePlan = try evaluatePlan(for: intent, config: config, memory: relevantMemory, query: query)

        let system = buildSystemPrompt(for: config, memory: relevantMemory)
        let maxTokens = min(config.maxTokensHint, effectivePlan.maxOutputTokens)

        return try await executeAICompletion(query: query, systemPrompt: system, config: config, maxTokens: maxTokens)
    }

    /// Explicit aspect entry (diagnostics, chamber awaken, Intents).
    func switchPersona(to id: String) async throws {
        let aspect = mapPersonaToAspect(id)
        visualState = .transitioning
        await applyAspect(aspect, reason: "explicit switch", force: true)
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

        let intent = Intent(kind: .remember, rawText: content, confidence: 1.0)
        let turnAspect = aspectPolicy.aspectForTurn(intent: intent)
        await applyAspect(turnAspect, reason: "remember")

        personaManager.updateTaskContext(
            description: "Capture memory: \(String(truncated.prefix(80)))",
            memoryHints: [String(truncated.prefix(120))]
        )

        await memoryManager.set(
            key: "note.brain.\(UUID().uuidString.prefix(8))",
            value: truncated,
            category: .temporary,
            metadata: ["source": "mercury-brain", "aspect": activeAspect.rawValue],
            importanceBoost: policy.writeImportanceHint,
            personaScope: nil
        )

        personality.noteInsight()
        visualState = .processing
        refreshLivingStatus()
        stabilizeVisualStateAfterSuccess()
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

    /// Structured capability invocations.
    func invoke(_ capability: Capability, payload: String = "") async throws -> String {
        switch capability.kind {
        case .memoryWrite:
            await remember(payload.isEmpty ? "(empty note)" : payload)
            return "Remembered."
        case .memoryRead:
            let items = retrieveSnapshot(limit: 5)
            if items.isEmpty { return "No matching memory." }
            return items.map { item in
                let snippet = String(item.value.prefix(140))
                return "[\(item.category.rawValue)] \(snippet)"
            }.joined(separator: "\n")
        case .memoryCorrect:
            await remember("Correction: \(payload)")
            return "Correction recorded."
        case .diagnose:
            return try await ask(
                payload.isEmpty
                    ? "Diagnose current device health, thermal, and power. Be precise."
                    : payload
            )
        case .express:
            return try await ask(payload.isEmpty ? "Summarize current status." : payload)
        case .plan, .invokeTool:
            throw AppError.unsupportedFeature(capability.name)
        }
    }

    func refreshLivingStatus() {
        let state = nexus.state
        let label = activeAspect.diagnosticLabel

        if let insight = state.recentInsights.first {
            primaryInsight = insight.title
            livingStatus = "\(label): \(insight.title)"
        } else if state.overallHealthScore < 50 {
            livingStatus = "\(label) watches rising pressure. Health \(state.overallHealthScore)."
            personality.increase(.skepticism, by: 0.04)
        } else if state.lowPowerMode {
            livingStatus = "\(label) notes low power. Conserving."
            personality.increase(.patience, by: 0.03)
        } else {
            livingStatus = "\(label) is present. The Sanctum holds."
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

    // MARK: - Aspect is source of truth

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

    private func mapPersonaToAspect(_ personaID: String) -> Aspect {
        switch personaID {
        case "forge": return .forge
        case "eternal": return .eternal
        default: return .quicksilver
        }
    }


}


// MARK: - Extracted AI logic
    // MARK: - Visual baseline

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

    // MARK: - Memory / budget helpers

    private func retrieveRelevantMemory() -> [MemoryItem] {
        retrieveSnapshot(limit: 5)
    }

    private func estimateContextTokens(systemHint: String, memory: [MemoryItem], query: String) -> Int {
        let memoryChars = memory.reduce(0) { $0 + $1.value.count }
        let totalChars = systemHint.count + memoryChars + query.count
        return totalChars / 4
    }

    // MARK: - Prompt

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

extension MercuryBrain {

    private func evaluatePlan(
        for intent: Intent,
        config: PersonaConfiguration,
        memory: [MemoryItem],
        query: String
    ) throws -> ResourcePlan {
        let estimatedTokens = estimateContextTokens(systemHint: config.systemPrompt, memory: memory, query: query)

        let plan = broker.defaultPlan(for: intent)
        let decision = broker.evaluate(
            IntelligenceBroker.TurnRequest(
                intent: intent,
                aspect: activeAspect,
                plan: plan,
                estimatedContextTokens: estimatedTokens
            )
        )

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

    private func executeAICompletion(
        query: String,
        systemPrompt: String,
        config: PersonaConfiguration,
        maxTokens: Int
    ) async throws -> String {
        do {
            let response = try await aiService.complete(
                prompt: query,
                systemPrompt: systemPrompt,
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
            visualState = .warning
            refreshLivingStatus()
            throw error
        }
    }
}
