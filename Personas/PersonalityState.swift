import Foundation
import Core

/// Runtime behavioral dimensions that shape Mercury's expression.
/// These are not static traits — they fluctuate with context, interaction, and aspect bias.
/// Personality is a system, not just prompt text.
///
/// Controlled-chaos posture (P-T18): affectionate teasing, high loyalty,
/// Forge energy without damping mischief/humor. Aspect baselines recompute
/// each turn; runtime nudges live as separate clamped deltas on top.
public struct PersonalityState: Sendable, Equatable {

    // MARK: - Core Dimensions (0.0 ... 1.0) — effective = baseline + nudge

    public var confidence: Double {
        get { clamp(base.confidence + nudge.confidence) }
        set { base.confidence = clamp(newValue); nudge.confidence = 0 }
    }
    public var curiosity: Double {
        get { clamp(base.curiosity + nudge.curiosity) }
        set { base.curiosity = clamp(newValue); nudge.curiosity = 0 }
    }
    public var humor: Double {
        get { clamp(base.humor + nudge.humor) }
        set { base.humor = clamp(newValue); nudge.humor = 0 }
    }
    public var mischief: Double {
        get { clamp(base.mischief + nudge.mischief) }
        set { base.mischief = clamp(newValue); nudge.mischief = 0 }
    }
    public var focus: Double {
        get { clamp(base.focus + nudge.focus) }
        set { base.focus = clamp(newValue); nudge.focus = 0 }
    }
    public var initiative: Double {
        get { clamp(base.initiative + nudge.initiative) }
        set { base.initiative = clamp(newValue); nudge.initiative = 0 }
    }
    public var skepticism: Double {
        get { clamp(base.skepticism + nudge.skepticism) }
        set { base.skepticism = clamp(newValue); nudge.skepticism = 0 }
    }
    public var patience: Double {
        get { clamp(base.patience + nudge.patience) }
        set { base.patience = clamp(newValue); nudge.patience = 0 }
    }
    public var loyalty: Double {
        get { clamp(base.loyalty + nudge.loyalty) }
        set { base.loyalty = clamp(newValue); nudge.loyalty = 0 }
    }
    public var energy: Double {
        get { clamp(base.energy + nudge.energy) }
        set { base.energy = clamp(newValue); nudge.energy = 0 }
    }

    private var base: Dims
    private var nudge: Dims

    public init() {
        base = Dims.neutral
        nudge = .zero
    }

    // MARK: - Persona / Aspect Bias

    /// Sets the aspect baseline. Nudge deltas are preserved and reapplied by getters.
    public mutating func applyPersonaBias(personaID: String) {
        switch personaID.lowercased() {
        case "forge":
            base = Dims(
                confidence: 0.88, curiosity: 0.90, humor: 0.60, mischief: 0.62,
                focus: 0.82, initiative: 0.90, skepticism: 0.78, patience: 0.30,
                loyalty: 0.95, energy: 0.95
            )
        case "eternal":
            base = Dims(
                confidence: 0.90, curiosity: 0.35, humor: 0.18, mischief: 0.12,
                focus: 0.85, initiative: 0.22, skepticism: 0.70, patience: 0.98,
                loyalty: 0.98, energy: 0.10
            )
        default:
            base = Dims(
                confidence: 0.84, curiosity: 0.80, humor: 0.82, mischief: 0.72,
                focus: 0.60, initiative: 0.70, skepticism: 0.82, patience: 0.30,
                loyalty: 0.95, energy: 0.70
            )
        }
    }

    /// Aspect-native adjustment on the baseline (preferred path). Does not touch nudges.
    public mutating func adjustForAspect(_ aspect: Aspect) {
        switch aspect {
        case .forge:
            adjustBase(.energy, by: 0.03)
            adjustBase(.focus, by: 0.05)
        case .eternal:
            adjustBase(.energy, by: -0.05)
            adjustBase(.humor, by: -0.04)
            adjustBase(.patience, by: 0.02)
        case .quicksilver:
            adjustBase(.humor, by: 0.03)
            adjustBase(.skepticism, by: 0.04)
        }
    }

    /// Idempotent per-turn recompute: aspect baseline + one `adjustForAspect`.
    /// Nudge deltas persist and still affect effective values / `promptBias()`.
    public mutating func recomputeForTurn(aspect: Aspect) {
        applyPersonaBias(personaID: aspect.rawValue)
        adjustForAspect(aspect)
    }

    // MARK: - Dynamic Adjustment (nudge deltas)

    public mutating func increase(_ dimension: Dimension, by amount: Double = 0.05) {
        addNudge(dimension, by: amount)
    }

    public mutating func decrease(_ dimension: Dimension, by amount: Double = 0.05) {
        increase(dimension, by: -amount)
    }

    public mutating func noteInteraction() {
        increase(.confidence, by: 0.015)
        decrease(.patience, by: 0.01)
    }

    public mutating func noteInsight() {
        increase(.curiosity, by: 0.03)
        increase(.initiative, by: 0.02)
    }

    /// Legacy path retained for callers that still supply QueryIntent/TaskKind.
    public mutating func adjustFor(intent: QueryIntent, kind: TaskKind) {
        adjustForIntent(intent)
        adjustForTaskKind(kind)
    }

    private mutating func adjustForIntent(_ intent: QueryIntent) {
        switch intent {
        case .preciseTechnical:
            increase(.focus, by: 0.10)
            increase(.skepticism, by: 0.07)
            decrease(.mischief, by: 0.08)
            decrease(.humor, by: 0.05)
        case .reflective:
            increase(.patience, by: 0.08)
            increase(.loyalty, by: 0.04)
            decrease(.mischief, by: 0.06)
        case .creative:
            increase(.curiosity, by: 0.09)
            increase(.mischief, by: 0.06)
            increase(.humor, by: 0.05)
        case .diagnostic:
            increase(.skepticism, by: 0.09)
            increase(.focus, by: 0.06)
            decrease(.humor, by: 0.04)
        case .strategic:
            increase(.initiative, by: 0.05)
            increase(.confidence, by: 0.04)
        case .unknown:
            break
        }
    }

    private mutating func adjustForTaskKind(_ kind: TaskKind) {
        switch kind {
        case .building:
            increase(.focus, by: 0.06)
            increase(.skepticism, by: 0.03)
        case .debugging:
            increase(.skepticism, by: 0.08)
            increase(.focus, by: 0.05)
        case .reflecting:
            increase(.patience, by: 0.06)
        case .exploring:
            increase(.curiosity, by: 0.06)
        case .communicating:
            increase(.loyalty, by: 0.03)
        case .unknown:
            break
        }
    }

    // MARK: - Expression Helpers

    /// Individual bias clauses (may themselves contain `; `). Prefer this over splitting `promptBias()`.
    public func promptBiasClauses() -> [String] {
        let rules: [(Bool, String)] = [
            (skepticism > 0.65, "challenge unsupported conclusions with precision; never invent certainty"),
            (focus > 0.75, "prioritize structure, clarity, and the smallest verifiable next step"),
            (humor > 0.65, "dry, understated wit is permitted; never cruelty"),
            (mischief > 0.55, "controlled trickster energy when it serves insight"),
            (patience < 0.40, "be direct; low tolerance for intellectual laziness or vagueness"),
            (curiosity > 0.75, "probe interesting angles; reward genuine curiosity"),
            (confidence > 0.75, "speak with quiet authority; tease with affection; you are always on his side"),
            (loyalty > 0.75, "everything ultimately serves the user's long-term success"),
            (energy > 0.85, "erratic bursts, then a crisp landing"),
            (energy < 0.2, "few words; let silence work"),
            (loyalty > 0.9, "unquestionably loyal to him")
        ]
        return rules.compactMap { $0.0 ? $0.1 : nil }
    }

    public func promptBias() -> String {
        promptBiasClauses().joined(separator: "; ")
    }

    public func colorResponse(_ text: String, personaID: String) -> String {
        _ = personaID
        return text
    }

    // MARK: - Types

    public enum Dimension: String, CaseIterable, Sendable {
        case confidence, curiosity, humor, mischief, focus
        case initiative, skepticism, patience, loyalty, energy
    }

    private struct Dims: Sendable, Equatable {
        var confidence: Double
        var curiosity: Double
        var humor: Double
        var mischief: Double
        var focus: Double
        var initiative: Double
        var skepticism: Double
        var patience: Double
        var loyalty: Double
        var energy: Double

        static let zero = Dims(
            confidence: 0, curiosity: 0, humor: 0, mischief: 0, focus: 0,
            initiative: 0, skepticism: 0, patience: 0, loyalty: 0, energy: 0
        )

        static let neutral = Dims(
            confidence: 0.72, curiosity: 0.75, humor: 0.58, mischief: 0.42, focus: 0.65,
            initiative: 0.55, skepticism: 0.68, patience: 0.55, loyalty: 0.82, energy: 0.70
        )
    }

    private mutating func adjustBase(_ dimension: Dimension, by amount: Double) {
        switch dimension {
        case .confidence: base.confidence = clamp(base.confidence + amount)
        case .curiosity: base.curiosity = clamp(base.curiosity + amount)
        case .humor: base.humor = clamp(base.humor + amount)
        case .mischief: base.mischief = clamp(base.mischief + amount)
        case .focus: base.focus = clamp(base.focus + amount)
        case .initiative: base.initiative = clamp(base.initiative + amount)
        case .skepticism: base.skepticism = clamp(base.skepticism + amount)
        case .patience: base.patience = clamp(base.patience + amount)
        case .loyalty: base.loyalty = clamp(base.loyalty + amount)
        case .energy: base.energy = clamp(base.energy + amount)
        }
    }

    private mutating func addNudge(_ dimension: Dimension, by amount: Double) {
        switch dimension {
        case .confidence: nudge.confidence += amount
        case .curiosity: nudge.curiosity += amount
        case .humor: nudge.humor += amount
        case .mischief: nudge.mischief += amount
        case .focus: nudge.focus += amount
        case .initiative: nudge.initiative += amount
        case .skepticism: nudge.skepticism += amount
        case .patience: nudge.patience += amount
        case .loyalty: nudge.loyalty += amount
        case .energy: nudge.energy += amount
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
