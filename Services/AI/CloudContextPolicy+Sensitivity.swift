import Foundation
import Core

/// Privacy gate for cloud fallback (single checkpoint, with the rest of CloudContextPolicy).
///
/// After an on-device failure, a turn may go to the cloud only when this cheap,
/// local check says it is not personal: health, distress, memories, contacts,
/// location, finance, identity or credentials. The check is deliberately
/// conservative (false positives keep a turn local; they never leak it).
extension CloudContextPolicy {
    /// Metadata flag the Brain sets when the turn is known to be personal (plain register latched).
    public static let personalTurnKey = "personal"

    /// True when the turn must stay on this device.
    public static func isPersonal(_ request: AIRequest) -> Bool {
        if request.metadata[personalTurnKey] == "1" { return true }
        if request.context.contains(where: { $0.kind == .memory || $0.kind == .device }) { return true }
        let recentUser = request.history.filter { $0.role == .user }.suffix(2).map(\.content)
        return ([request.prompt] + recentUser).contains(where: isPersonalText)
    }

    /// Cloud fallback after an on-device failure is allowed only for non-personal turns.
    public static func allowsCloudFallback(_ request: AIRequest) -> Bool {
        !isPersonal(request)
    }

    /// Phrase / whole-word match over normalized text. No network, no model.
    public static func isPersonalText(_ text: String) -> Bool {
        let lower = RegisterPolicy.normalize(text)
        guard !lower.isEmpty else { return false }
        if personalPhrases.contains(where: { lower.contains($0) }) { return true }
        let words = Set(lower.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init))
        return !words.isDisjoint(with: personalWords)
    }

    /// Multi-word phrases (substring match).
    static let personalPhrases: [String] = [
        // Memory / what Mercury knows about the owner
        "remember when", "do you remember", "what do you know about me", "my notes", "my memories",
        "you remember", "about me",
        // Distress / safety
        "kill myself", "hurt myself", "self harm", "self-harm", "end it all", "can't cope", "cant cope",
        "falling apart", "panic attack", "broke up",
        // Health
        "my health", "my doctor", "my therapist", "my meds", "my medication", "my symptoms", "blood pressure",
        "mental health", "my chest", "my period",
        // Contacts / relationships
        "my mom", "my dad", "my wife", "my husband", "my partner", "my girlfriend", "my boyfriend",
        "my kid", "my son", "my daughter", "my sister", "my brother", "my family", "my friend",
        "phone number", "my contacts", "email address",
        // Location
        "where am i", "my location", "my address", "home address", "where i live", "near me", "my home",
        // Finance / identity / credentials
        "my bank", "my salary", "my debt", "credit card", "bank account", "account number", "my taxes",
        "social security", "my password", "pin code", "my passport", "my loan", "my rent"
    ]

    /// Single words (whole-word match).
    static let personalWords: Set<String> = [
        // Health
        "diagnosis", "symptom", "symptoms", "medication", "prescription", "doctor", "therapist", "therapy",
        "hospital", "pregnant", "pregnancy", "depressed", "depression", "anxiety", "anxious", "suicidal",
        "suicide", "overdose", "fever", "cancer", "illness", "rash", "injury",
        // Distress
        "lonely", "overwhelmed", "grieving", "abuse", "abused", "scared", "panic",
        // Finance / identity
        "salary", "mortgage", "bankruptcy", "debt", "iban", "ssn", "password", "passcode",
        // Location
        "address", "gps", "coordinates",
        // Legal
        "lawsuit", "divorce"
    ]
}
