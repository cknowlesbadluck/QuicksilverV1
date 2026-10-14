import Foundation
import Core

/// Privacy gate for cloud fallback (single checkpoint, with the rest of CloudContextPolicy).
///
/// After an on-device failure, a turn may go to the cloud only when this cheap,
/// local check says it is not personal: health, distress, memories, contacts,
/// location, finance, identity or credentials. The check is deliberately
/// conservative (false positives keep a turn local; they never leak it).
extension CloudContextPolicy {
    /// Metadata flag a caller sets when the turn is known to be personal. Not derived from the
    /// plain register (that is a presentation choice; e.g. "be serious" is not sensitive).
    public static let personalTurnKey = "personal"

    /// True when the turn must stay on this device.
    public static func isPersonal(_ request: AIRequest) -> Bool {
        if request.metadata[personalTurnKey] == "1" { return true }
        // Memory blocks are personal. Coarse device blocks are already sanitized to an
        // allowlist ("thermal nominal"), so they don't make a turn personal on their own.
        if request.context.contains(where: { $0.kind == .memory }) { return true }
        // Every outbound history message counts, assistant turns included: an earlier
        // on-device answer can carry memory or health details.
        return ([request.prompt] + request.history.map(\.content)).contains(where: isPersonalText)
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
        if valueLooksLikeCredential(text) || containsEmailAddress(lower) || containsSecretShapedToken(text) { return true }
        if containsStructuredIdentifier(text) { return true }
        let words = Set(lower.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map(String.init))
        return !words.isDisjoint(with: personalWords)
    }

    /// Phone numbers (7+ digits in one run of digits/spaces/()-.+) and SSN-shaped values.
    static func containsStructuredIdentifier(_ text: String) -> Bool {
        if text.range(of: #"\b\d{3}-\d{2}-\d{4}\b"#, options: .regularExpression) != nil { return true }
        let pattern = #"\+?\(?\d[\d\s().-]{5,}\d"#
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: pattern, options: .regularExpression, range: searchRange) {
            let match = text[range].trimmingCharacters(in: .whitespaces)
            let isDate = match.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            if !isDate, match.filter(\.isNumber).count >= 7 { return true }
            searchRange = range.upperBound..<text.endIndex
        }
        return false
    }

    static func containsEmailAddress(_ lower: String) -> Bool {
        lower.range(of: #"[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"#, options: .regularExpression) != nil
    }

    /// Long opaque tokens (keys like `sk-…`, 24+ chars of letters/digits/-_ with a digit).
    static func containsSecretShapedToken(_ text: String) -> Bool {
        text.split(whereSeparator: \.isWhitespace).contains { word in
            word.count >= 24
                && word.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
                && word.contains(where: \.isNumber)
        } || text.range(of: #"\bsk-[A-Za-z0-9_-]{8,}"#, options: .regularExpression) != nil
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
        "social security", "my password", "api key", "my email", "my phone", "pin code", "my passport", "my loan", "my rent"
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
        "salary", "mortgage", "bankruptcy", "debt", "iban", "ssn", "password", "passcode", "token", "secret",
        // Location
        "address", "gps", "coordinates",
        // Legal
        "lawsuit", "divorce"
    ]
}
