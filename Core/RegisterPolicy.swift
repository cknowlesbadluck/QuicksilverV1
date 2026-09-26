import Foundation

/// Conversational register for Mercury's voice.
/// `playful` is the default controlled-chaos surface; `plain` is the mask slip.
public enum Register: String, Sendable, Equatable, CaseIterable {
    case playful
    case plain
}

/// Pure policy: chooses `Register` from user text, pre-turn `VisualState`, and `Intent`.
///
/// Once `.plain`, the register stays latched across follow-up turns until an
/// explicit lightening signal from the owner (joke / roast / lighten up) or a
/// new session (caller resets `previous` to `.playful`).
public struct RegisterPolicy: Sendable {

    public init() {}

    /// Evaluate the register for a single turn.
    /// - Parameters:
    ///   - text: raw user utterance
    ///   - visualState: Brain's VisualState **before** it moves to `.thinking`
    ///   - intent: classified desire for this turn (reserved for future signals)
    ///   - previous: latched register from the prior turn (`.playful` for a new session)
    ///   - thermalState: Nexus thermal description (`serious` / `critical` → plain)
    ///   - nexusSeverityCritical: true when Nexus reports a critical severity signal
    public func evaluate(
        text: String,
        visualState: VisualState,
        intent: Intent,
        previous: Register = .playful,
        thermalState: String? = nil,
        nexusSeverityCritical: Bool = false
    ) -> Register {
        _ = intent // Contract surface; text + environment drive decisions today.
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if forcesPlain(
            lower: lower,
            visualState: visualState,
            thermalState: thermalState,
            nexusSeverityCritical: nexusSeverityCritical
        ) {
            return .plain
        }

        if previous == .plain {
            if isLightening(lower) {
                return .playful
            }
            return .plain
        }

        return .playful
    }

    // MARK: - Plain triggers

    private func forcesPlain(
        lower: String,
        visualState: VisualState,
        thermalState: String?,
        nexusSeverityCritical: Bool
    ) -> Bool {
        if visualState == .critical { return true }
        if nexusSeverityCritical { return true }
        if hasSeriousThermal(thermalState) { return true }
        if lower.isEmpty { return false }
        return Self.plainPhrases.contains { lower.contains($0) }
    }

    private func hasSeriousThermal(_ thermalState: String?) -> Bool {
        guard let thermal = thermalState?.lowercased() else { return false }
        return thermal.contains("serious") || thermal.contains("critical")
    }

    private func isLightening(_ lower: String) -> Bool {
        Self.lighteningPhrases.contains { lower.contains($0) }
    }

    // MARK: - Phrase tables

    /// Substrings that trigger an immediate mask slip. Kept as phrases (not bare
    /// tokens like "health") so system diagnostics ("system health") stay playful.
    private static let plainPhrases: [String] = [
        // Distress / overwhelm / exhaustion / fear / self-criticism
        "i'm overwhelmed", "im overwhelmed", "overwhelmed",
        "i'm exhausted", "im exhausted", "exhausted",
        "i'm so lonely", "im so lonely", "lonely",
        "i'm scared", "im scared", "i'm afraid", "im afraid",
        "i feel like a failure", "i'm a failure", "im a failure",
        "i can't cope", "i cant cope", "falling apart",
        "panic", "anxious", "anxiety",
        // Grief
        "i'm grieving", "im grieving", "grieving",
        "someone died", "passed away", "i miss them",
        // Health / medical
        "i have a fever", "my chest hurts", "see a doctor",
        "medical", "hospital", "i'm sick", "im sick",
        "my health", "diagnosis",
        // Self-harm / safety
        "self-harm", "self harm", "hurt myself",
        "kill myself", "end it all", "suicidal", "988",
        // Family
        "my mom", "my dad", "my family", "family emergency",
        "my parents", "my sister", "my brother", "my kid",
        // Relationships
        "my relationship", "we broke up", "my partner",
        "divorce", "broke up with",
        // Money / legal
        "can't pay rent", "cant pay rent", "bankruptcy",
        "lawsuit", "legal trouble", "i'm broke", "im broke",
        "money trouble", "owe money",
        // Destructive / irreversible
        "delete all my memories", "clear all memory", "wipe everything",
        "erase all memories",
        // Explicit seriousness
        "tell me straight", "be serious", "no jokes", "drop the act"
    ]

    /// Owner-driven signals that may release a latched plain register.
    private static let lighteningPhrases: [String] = [
        "tell me a joke", "tell me joke", "make me laugh",
        "roast my", "roast me", "lighten up", "lighten the mood",
        "back to joking", "be funny", "joke around"
    ]
}
