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

    /// Memories that reach the small on-device model (local only, never cloud).
    static let onDeviceMemoryLimit = 3

    /// Request metadata for the turn (snapshotted `config`): the compact local
    /// prompt (compact core + aspect + up to 3 memories + device line, with the
    /// plain-mode directive when plain is latched), plus the offline flag so a
    /// failed or unavailable local answer never falls back to the cloud.
    static func requestMetadata(
        _ config: PersonaConfiguration,
        _ register: Register,
        _ memories: [MemoryItem],
        _ state: NexusState
    ) -> [String: String] {
        let aspect = aspect(forPersonaID: config.id)
        var metadata = [
            AIService.onDeviceInstructionsKey: PromptComposer.compose(
                core: PromptManager.coreCompactIdentity(),
                aspect: config.systemPrompt,
                memory: Array(memories.prefix(onDeviceMemoryLimit)),
                device: localDeviceLine(state),
                aspectLabel: aspect.diagnosticLabel,
                plainMode: register == .plain,
                destination: .onDevice
            )
        ]
        if state.networkStatus == "disconnected" { metadata[AIService.offlineKey] = "1" }
        return metadata
    }

    static func localDeviceLine(_ state: NexusState) -> String {
        let battery = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "unknown"
        return "health \(state.overallHealthScore), battery \(battery)"
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
    /// M3.5-T4: user/assistant pairs kept for the on-device route (local only).
    static let onDeviceTurns = 4

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
    /// On-device, memory and device context land in one delimited `UntrustedNotes` block (M3-T12).
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
        let device = includeLocal ? localDeviceLine(state) : ""
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
