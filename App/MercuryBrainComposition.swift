import Foundation
import Core
import Memory
import Personas
import Nexus
import ServicesAI

/// Pure composition helpers for MercuryBrain.
///
/// Stateless: every input is passed in explicitly, so the Brain keeps sole
/// ownership of its dependencies, VisualState and aspect. Only MercuryBrain
/// should call these.
enum BrainComposition {

    /// Living-status narration for the current Nexus state.
    /// Thin adapter over `LivingNarration` (Personas) — no aspect label.
    typealias LivingReading = LivingNarration.Reading

    static func livingReading(state: NexusState) -> LivingReading {
        LivingNarration.reading(
            insightTitle: state.recentInsights.first?.title,
            healthScore: state.overallHealthScore,
            lowPowerMode: state.lowPowerMode,
            networkDisconnected: state.networkStatus == "disconnected"
        )
    }

    static func brokerDecision(
        _ broker: IntelligenceBroker,
        intent: Intent,
        aspect: Aspect,
        tokens: Int
    ) -> IntelligenceBroker.Decision {
        let plan = broker.defaultPlan(for: intent)
        return broker.evaluate(
            IntelligenceBroker.TurnRequest(
                intent: intent,
                aspect: aspect,
                plan: plan,
                estimatedContextTokens: tokens
            )
        )
    }

    static func aspect(forPersonaID personaID: String) -> Aspect {
        switch personaID {
        case "forge": return .forge
        case "eternal": return .eternal
        default: return .quicksilver
        }
    }

    /// Environmental VisualState baseline derived from Nexus state.
    static func environmentalBaseline(state: NexusState, aspect: Aspect) -> VisualState {
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
        return aspect.defaultVisualState
    }

    /// Prior user/assistant pairs kept on a Brain turn. Current prompt is not history.
    static let maxConversationTurns = 8

    static func recentHistory(_ messages: [Message], maxTurns: Int = maxConversationTurns) -> [Message] {
        let maxMessages = max(0, maxTurns) * 2
        guard messages.count > maxMessages else { return messages }
        return Array(messages.suffix(maxMessages))
    }

    /// Estimate outbound prompt size. Pass the capped context blocks that leave the device
    /// (or empty when those texts are already folded into `systemHint` via systemAppendix).
    static func estimateContextTokens(
        systemHint: String,
        serializedContext: [GatewayContextBlock] = [],
        query: String,
        history: [Message] = []
    ) -> Int {
        let contextChars = serializedContext.reduce(0) { $0 + $1.text.count }
        let historyChars = history.reduce(0) { $0 + $1.content.count }
        return (systemHint.count + contextChars + historyChars + query.count) / 4
    }

    /// Cloud prompts never embed memories or raw Nexus device text — CloudContextPolicy owns that.
    static func systemPrompt(
        base: String,
        bias: String,
        memory: [MemoryItem],
        state: NexusState,
        aspect: Aspect,
        owner: String = PromptComposer.defaultOwnerName,
        destination: PromptComposer.Destination = .cloud,
        plainMode: Bool = false
    ) -> String {
        let includeLocal = destination == .onDevice
        let memoryForPrompt = includeLocal ? memory : []
        let device: String
        if includeLocal {
            let health = state.overallHealthScore
            let battery = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "unknown"
            device = "Device context (private): health \(health), battery \(battery)."
        } else {
            device = ""
        }
        return PromptComposer.compose(
            core: PromptManager.coreIdentity(),
            aspect: base,
            bias: bias,
            memory: memoryForPrompt,
            device: device,
            aspectLabel: aspect.diagnosticLabel,
            plainMode: plainMode,
            owner: owner,
            destination: destination
        )
    }

    struct CloudAskPayload {
        let level: CloudContextLevel
        let history: [Message]
        let context: [GatewayContextBlock]
    }

    /// Build CloudContextPolicy blocks for one outbound Ask. `level` is already resolved.
    static func cloudPayload(
        question: String,
        history: [Message],
        memories: [MemoryItem],
        state: NexusState,
        level: CloudContextLevel
    ) -> CloudAskPayload {
        let deviceLine = CloudContextPolicy.coarseDeviceLine(
            batteryLevel: state.batteryLevel,
            thermalState: state.thermalState,
            lowPowerMode: state.lowPowerMode
        )
        let blocks = CloudContextPolicy.assemble(
            CloudContextInput(
                question: question,
                recentTurns: history.map(\.content),
                memories: memories,
                coarseDeviceLine: deviceLine
            ),
            level: level
        )
        return CloudAskPayload(
            level: level,
            history: CloudContextPolicy.cappedHistory(history, level: level),
            context: CloudContextPolicy.gatewayContext(from: blocks)
        )
    }
}
