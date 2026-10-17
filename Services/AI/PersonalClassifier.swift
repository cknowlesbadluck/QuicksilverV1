import Foundation
import NaturalLanguage

/// On-device "is this personal?" check for the privacy gate. NaturalLanguage public APIs only;
/// no network, no model download, no third-party code.
///
/// Runs only after the phrase and word lists find nothing. Fail-closed by design: when the text
/// is self-referential ("my", "me", "our"…) and the classifier can't decide (no sentence
/// embedding on this device), the turn is treated as personal and stays on device.
/// Text with no possessive or objective first person ("how do I sort an array") is never
/// flagged here, so knowledge questions keep their cloud fallback.
public enum PersonalClassifier {
    public enum Verdict: Equatable, Sendable {
        case impersonal
        case personal(Reason)
    }

    public enum Reason: String, Sendable {
        case namedPerson        // self-reference plus a person's name ("my friend John Smith")
        case domain             // self-reference plus a personal-domain word ("my rent", "my knee")
        case domainNeighbor     // self-reference plus a word whose meaning is close to a domain seed
        case semantic           // close to a personal prototype sentence
        case undecidedFailClosed // self-reference, but no embedding to decide with
    }

    /// Cosine distance (0 identical … 2 opposite) at or below which text counts as personal.
    public static let semanticThreshold = 0.85

    /// Self-referential markers. "I" alone is excluded: "how do I…" is a knowledge question.
    static let selfReference: Set<String> = [
        "my", "mine", "myself", "me", "our", "ours", "ourselves", "us", "we", "we're", "we've", "we'll", "we'd"
    ]

    /// Personal domains, as lemmas. Only consulted when the text is self-referential, so the words
    /// can be broader than the gate's always-on list ("my rent", not "rent a car").
    static let domainLemmas: [String: Set<String>] = [
        "health": [
            "heart", "knee", "chest", "blood", "sugar", "pain", "ache", "swollen", "swell", "sleep",
            "insomnia", "dizzy", "nausea", "cough", "migraine", "headache", "allergy", "period", "weight", "pill",
            "dose", "surgery", "lump", "tooth", "breathing", "breathe"
        ],
        "finance": [
            "rent", "paycheck", "wage", "owe", "loan", "savings", "bill", "overdraft",
            "pension", "invoice", "afford", "broke", "income", "tax", "bank", "money"
        ],
        "home": [
            "neighbourhood", "neighborhood", "flat", "apartment", "home", "house", "landlord", "commute",
            "street"
        ],
        "people": [
            "mum", "mom", "dad", "mother", "father", "brother", "sister", "wife", "husband", "girlfriend",
            "boyfriend", "partner", "son", "daughter", "child", "kid", "baby", "friend", "neighbour", "neighbor",
            "family", "parent", "grandma", "grandmother", "grandpa", "grandfather", "ex", "wedding", "relationship"
        ],
        "feelings": [
            "feel", "lonely", "sad", "overwhelm", "overwhelming", "anxious", "worried", "worry", "afraid",
            "stress", "stressed", "upset", "angry", "hurt", "cry", "miss", "grief", "unsafe", "ashamed", "argue"
        ],
        "work": [
            "manager", "boss", "colleague", "coworker", "interview", "interviewing", "fired",
            "promotion", "resign", "layoff", "hr"
        ]
    ]

    static let allDomainLemmas: Set<String> = domainLemmas.values.reduce(into: []) { $0.formUnion($1) }

    /// Short descriptions of what personal turns are about. Compared by meaning, not words.
    static let prototypes = [
        "my health, symptoms, diagnosis or medication",
        "my feelings, anxiety, depression or mental state",
        "my relationship with my partner, family or friends",
        "my money, salary, debt, bank account or taxes",
        "where I live, my home address or my location",
        "my job situation, my boss or my performance review",
        "my passwords, account logins or private codes",
        "my children, my pregnancy or my family plans"
    ]

    /// Word-embedding cosine distance at or below which a word counts as a personal-domain neighbour.
    public static let wordNeighborThreshold = 0.0 // calibration probe: disabled until measured

    /// One seed word per domain; neighbours in Apple's word embedding generalise the lexicon.
    static let domainSeeds = ["illness", "money", "family", "home", "emotion", "job"]

    public static func classify(
        _ text: String,
        similarity: SentenceSimilarity = NLSentenceSimilarity.shared,
        wordNeighbors: WordSimilarity = NLWordSimilarity.shared
    ) -> Verdict {
        let words = lowercasedWords(text)
        guard !words.isDisjoint(with: selfReference) else { return .impersonal }
        if containsPersonName(text) { return .personal(.namedPerson) }
        if !words.union(CloudContextPolicy.lemmas(text)).isDisjoint(with: allDomainLemmas) {
            return .personal(.domain)
        }
        let neighbor = wordNeighbors.minimumDistance(from: words, toSeeds: domainSeeds)
        if let neighbor, neighbor <= wordNeighborThreshold { return .personal(.domainNeighbor) }
        let distance = similarity.minimumDistance(from: text, to: prototypes)
        if let distance, distance <= semanticThreshold { return .personal(.semantic) }
        // Self-referential and nothing could decide: no embedding of either kind on this device.
        if neighbor == nil && distance == nil { return .personal(.undecidedFailClosed) }
        return .impersonal
    }

    public static func isPersonal(
        _ text: String,
        similarity: SentenceSimilarity = NLSentenceSimilarity.shared,
        wordNeighbors: WordSimilarity = NLWordSimilarity.shared
    ) -> Bool {
        classify(text, similarity: similarity, wordNeighbors: wordNeighbors) != .impersonal
    }

    static func lowercasedWords(_ text: String) -> Set<String> {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var words: Set<String> = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            words.insert(text[range].lowercased())
            return true
        }
        return words
    }

    static func containsPersonName(_ text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found = false
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, _ in
            if tag == .personalName { found = true }
            return !found
        }
        return found
    }
}

/// Sentence similarity source. `nil` means "can't decide on this device".
public protocol SentenceSimilarity: Sendable {
    func minimumDistance(from text: String, to candidates: [String]) -> Double?
}

/// Apple's on-device English sentence embedding (public NaturalLanguage API).
public final class NLSentenceSimilarity: SentenceSimilarity, Sendable {
    public static let shared = NLSentenceSimilarity()
    private init() {}

    public func minimumDistance(from text: String, to candidates: [String]) -> Double? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        let distances = candidates.map { embedding.distance(between: text, and: $0, distanceType: .cosine) }
        // NLEmbedding reports 2.0 when it can't embed a string; treat all-unknown as undecided.
        let known = distances.filter { $0.isFinite && $0 < 2.0 }
        return known.min()
    }
}

/// Word similarity source. `nil` means "no word embedding on this device".
public protocol WordSimilarity: Sendable {
    func minimumDistance(from words: Set<String>, toSeeds seeds: [String]) -> Double?
}

/// Apple's on-device English word embedding (public NaturalLanguage API).
public final class NLWordSimilarity: WordSimilarity, Sendable {
    public static let shared = NLWordSimilarity()
    private init() {}

    /// Common function words never count as domain neighbours.
    static let ignored: Set<String> = PersonalClassifier.selfReference.union([
        "i", "a", "an", "the", "to", "of", "and", "or", "is", "are", "be", "it", "in", "on", "at", "for",
        "with", "about", "how", "what", "why", "do", "does", "can", "should", "this", "that"
    ])

    public func minimumDistance(from words: Set<String>, toSeeds seeds: [String]) -> Double? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return nil }
        let distances = words.subtracting(Self.ignored).flatMap { word in
            seeds.map { embedding.distance(between: word, and: $0, distanceType: .cosine) }
        }
        let known = distances.filter { $0.isFinite && $0 < 2.0 }
        return known.min() ?? 2.0
    }
}
