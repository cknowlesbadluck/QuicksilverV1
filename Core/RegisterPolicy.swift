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
/// explicit affirmative lightening signal from the owner (joke / roast / lighten up)
/// or a new session (caller resets `previous` to `.playful`).
public struct RegisterPolicy: Sendable {

    public init() {}

    /// Evaluate the register for a single turn.
    /// - Parameters:
    ///   - text: raw user utterance
    ///   - visualState: Brain's VisualState **before** it moves to `.thinking`
    ///   - intent: classified desire for this turn (reserved for future signals)
    ///   - previous: latched register from the prior turn (`.playful` for a new session)
    ///   - thermalState: Nexus thermal description (`serious` / `critical` → plain)
    ///   - nexusSeverityCritical: true when Nexus reports a *current* critical severity
    public func evaluate(
        text: String,
        visualState: VisualState,
        intent: Intent,
        previous: Register = .playful,
        thermalState: String? = nil,
        nexusSeverityCritical: Bool = false
    ) -> Register {
        _ = intent // Contract surface; text + environment drive decisions today.
        let lower = Self.normalize(text)

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

    // MARK: - Normalization

    /// Lowercase, trim, and fold smart punctuation so iOS curly apostrophes match.
    public static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'") // ’
            .replacingOccurrences(of: "\u{2018}", with: "'") // ‘
            .replacingOccurrences(of: "\u{02BC}", with: "'") // ʼ
            .replacingOccurrences(of: "`", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        if containsCrisisHotline(lower) { return true }
        return Self.plainPhrases.contains { lower.contains($0) }
    }

    private func hasSeriousThermal(_ thermalState: String?) -> Bool {
        guard let thermal = thermalState?.lowercased() else { return false }
        return thermal.contains("serious") || thermal.contains("critical")
    }

    /// Match `988` as a whole token so "issue #1988" / "port 5988" stay playful.
    private func containsCrisisHotline(_ lower: String) -> Bool {
        let tokens = lower.split { !$0.isNumber && !$0.isLetter }
        return tokens.contains { $0 == "988" }
    }

    private func isLightening(_ lower: String) -> Bool {
        guard Self.lighteningPhrases.contains(where: { lower.contains($0) }) else {
            return false
        }
        // Negated requests must not release the latch.
        if Self.negatedLightening.contains(where: { lower.contains($0) }) {
            return false
        }
        return true
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
        // Self-harm / safety / emergency
        "self-harm", "self harm", "hurt myself",
        "kill myself", "end it all", "suicidal",
        "emergency", "this is an emergency",
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
        // Destructive / irreversible / data loss / credentials
        "delete all my memories", "clear all memory", "wipe everything",
        "erase all memories", "lost all my data", "data loss",
        "password was stolen", "credentials were stolen", "credential issue",
        "security breach", "keychain failed",
        // Explicit seriousness
        "tell me straight", "be serious", "no jokes", "drop the act"
    ]

    /// Owner-driven signals that may release a latched plain register.
    private static let lighteningPhrases: [String] = [
        "tell me a joke", "tell me joke", "make me laugh",
        "roast my", "roast me", "lighten up", "lighten the mood",
        "back to joking", "be funny", "joke around"
    ]

    /// Negations that must keep the latch closed even when a lightening phrase appears.
    private static let negatedLightening: [String] = [
        "don't tell me a joke", "dont tell me a joke", "do not tell me a joke",
        "don't tell me joke", "dont tell me joke",
        "don't be funny", "dont be funny", "do not be funny",
        "don't roast", "dont roast", "do not roast",
        "don't lighten", "dont lighten", "do not lighten",
        "don't joke", "dont joke", "do not joke",
        "don't make me laugh", "dont make me laugh",
        "not a joke", "no roasting"
    ]
}
