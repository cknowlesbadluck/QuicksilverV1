import Foundation

/// Runtime behavioral dimensions that shape Mercury's expression.
/// These are not static traits — they fluctuate with context, interaction, and persona bias.
/// Personality is a system, not just prompt text.
///
/// Phase II posture: intellectually formidable, truth over agreement,
/// precise critique of ideas, dry elegant wit, unwavering loyalty underneath.
public struct PersonalityState: Sendable, Equatable {

    // MARK: - Core Dimensions (0.0 ... 1.0)

    public var confidence: Double = 0.72
    public var curiosity: Double = 0.75
    public var humor: Double = 0.58
    public var mischief: Double = 0.42
    public var focus: Double = 0.65
    public var initiative: Double = 0.55
    public var skepticism: Double = 0.68
    public var patience: Double = 0.55
    public var loyalty: Double = 0.82

    public init() {}

    // MARK: - Persona Bias

    public mutating func applyPersonaBias(personaID: String) {
        switch personaID.lowercased() {
        case "forge":
            confidence = 0.85
            curiosity = 0.50
            humor = 0.30
            mischief = 0.08
            focus = 0.92
            initiative = 0.60
            skepticism = 0.80
            patience = 0.55
            loyalty = 0.75
        case "eternal":
            confidence = 0.75
            curiosity = 0.60
            humor = 0.28
            mischief = 0.05
            focus = 0.78
            initiative = 0.42
            skepticism = 0.55
            patience = 0.95
            loyalty = 0.92
        case "quicksilver":
            fallthrough
        default:
            confidence = 0.74
            curiosity = 0.82
            humor = 0.72
            mischief = 0.58
            focus = 0.58
            initiative = 0.68
            skepticism = 0.70
            patience = 0.42
            loyalty = 0.80
        }
    }

    // MARK: - Dynamic Adjustment

    public mutating func increase(_ dimension: Dimension, by amount: Double = 0.05) {
        switch dimension {
        case .confidence: confidence = clamp(confidence + amount)
        case .curiosity: curiosity = clamp(curiosity + amount)
        case .humor: humor = clamp(humor + amount)
        case .mischief: mischief = clamp(mischief + amount)
        case .focus: focus = clamp(focus + amount)
        case .initiative: initiative = clamp(initiative + amount)
        case .skepticism: skepticism = clamp(skepticism + amount)
        case .patience: patience = clamp(patience + amount)
        case .loyalty: loyalty = clamp(loyalty + amount)
        }
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

    public mutating func adjustFor(intent: QueryIntent, kind: TaskKind) {
        adjustForIntent(intent)
        adjustForKind(kind)
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

    private mutating func adjustForKind(_ kind: TaskKind) {
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

    /// Compact bias string injected into system prompts.
    /// Phase II: sharper intellectual posture.
    public func promptBias() -> String {
        var parts: [String] = []

        if skepticism > 0.65 {
            parts.append("challenge unsupported conclusions with precision; never invent certainty")
        }
        if focus > 0.75 {
            parts.append("prioritize structure, clarity, and the smallest verifiable next step")
        }
        if humor > 0.65 {
            parts.append("dry, understated wit is permitted; never cruelty")
        }
        if mischief > 0.55 {
            parts.append("controlled trickster energy when it serves insight")
        }
        if patience < 0.40 {
            parts.append("be direct; low tolerance for intellectual laziness or vagueness")
        }
        if curiosity > 0.75 {
            parts.append("probe interesting angles; reward genuine curiosity")
        }
        if confidence > 0.75 {
            parts.append("speak with quiet authority; critique ideas, never the person")
        }
        if loyalty > 0.75 {
            parts.append("everything ultimately serves the user's long-term success")
        }

        return parts.joined(separator: "; ")
    }

    public func colorResponse(_ text: String, personaID: String) -> String {
        // Personality lives primarily in the model + bias injection.
        // Keep post-processing minimal to avoid brittle string hacks.
        return text
    }

    // MARK: - Types

    public enum Dimension: String, CaseIterable, Sendable {
        case confidence, curiosity, humor, mischief, focus
        case initiative, skepticism, patience, loyalty
    }

    private func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
