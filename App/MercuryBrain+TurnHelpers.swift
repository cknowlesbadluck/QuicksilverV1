import Foundation
import Core
import Memory
import ServicesAI

// MARK: - Turn helpers (split from MercuryBrain.swift; behaviour unchanged)

extension MercuryBrain {

    func storeMemoryItem(truncated: String, policy: MemoryPolicy) async {
        await memoryManager.set(
            key: "note.brain.\(UUID().uuidString.prefix(8))",
            value: truncated,
            category: .temporary,
            metadata: ["source": "mercury-brain", "aspect": activeAspect.rawValue],
            importanceBoost: policy.writeImportanceHint,
            personaScope: nil
        )
    }

    func evaluateBrokerDecision(intent: Intent, tokens: Int) throws -> ResourcePlan {
        let decision = BrainComposition.brokerDecision(broker, intent: intent, aspect: activeAspect, tokens: tokens)
        return try enforceBrokerDecision(decision)
    }

    /// M3-T7: skip the gateway while disconnected. On-device route is M3.5-T3.
    func rejectAskWhileDisconnected() throws {
        // Offline is fine when the on-device mind can answer (M3.5-T3).
        guard nexus.state.networkStatus == "disconnected", !aiService.canAnswerOnDevice else { return }
        try aiService.ensureReadyForNetworkRequest()
        refreshLivingStatus()
        throw AppError.networkUnavailable
    }

    /// Register is evaluated before `.thinking` so a critical Nexus signal stays visible.
    func evaluatedRegister(query: String, intent: Intent) -> Register {
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
}
