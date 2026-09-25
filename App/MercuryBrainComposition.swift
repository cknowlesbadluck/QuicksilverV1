import Foundation
import Core
import Memory
import Personas
import Nexus

/// Pure composition helpers for MercuryBrain.
///
/// Stateless: every input is passed in explicitly, so the Brain keeps sole
/// ownership of its dependencies, VisualState and aspect. Only MercuryBrain
/// should call these.
enum BrainComposition {

    /// Living-status narration for the current Nexus state.
    struct LivingReading {
        let text: String
        let insightTitle: String?
        let nudge: (dimension: PersonalityState.Dimension, amount: Double)?
    }

    static func livingReading(state: NexusState, label: String) -> LivingReading {
        if let insight = state.recentInsights.first {
            return LivingReading(text: "\(label): \(insight.title)", insightTitle: insight.title, nudge: nil)
        }
        if state.overallHealthScore < 50 {
            return LivingReading(
                text: "\(label) watches rising pressure. Health \(state.overallHealthScore).",
                insightTitle: nil,
                nudge: (.skepticism, 0.04)
            )
        }
        if state.lowPowerMode {
            return LivingReading(text: "\(label) notes low power. Conserving.", insightTitle: nil, nudge: (.patience, 0.03))
        }
        return LivingReading(text: "\(label) is present. The Sanctum holds.", insightTitle: nil, nudge: nil)
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

    static func estimateContextTokens(systemHint: String, memory: [MemoryItem], query: String) -> Int {
        let memoryChars = memory.reduce(0) { $0 + $1.value.count }
        return (systemHint.count + memoryChars + query.count) / 4
    }

    static func systemPrompt(
        base: String,
        bias: String,
        memory: [MemoryItem],
        state: NexusState,
        aspect: Aspect
    ) -> String {
        var prompt = base
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
                prompt += "- [\(item.category.rawValue)] \(String(item.value.prefix(180)))\n"
            }
        }

        let health = state.overallHealthScore
        let battery = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "unknown"
        prompt += "\n\nDevice context (private): health \(health), battery \(battery)."
        prompt += "\nActive aspect: \(aspect.diagnosticLabel)."
        return prompt
    }
}
