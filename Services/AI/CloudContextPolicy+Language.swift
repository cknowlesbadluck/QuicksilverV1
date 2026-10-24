import Foundation
import NaturalLanguage

/// On-device NaturalLanguage help for the privacy gate (public API, no network, no model download).
/// - Lemmas catch inflections the word list misses ("medications", "hospitals", "symptoms").
/// - The phrase and word lists are English only, so text that is confidently another
///   language fails closed: it's treated as personal and never falls back to the cloud.
extension CloudContextPolicy {
    /// Minimum letters before language identification is trusted.
    static let languageMinimumLetters = 16
    /// Confidence above which text is treated as "not English".
    static let nonEnglishConfidence = 0.9

    static func isConfidentlyNonEnglish(_ text: String) -> Bool {
        guard text.filter(\.isLetter).count >= languageMinimumLetters else { return false }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first else { return false }
        return language != .english && confidence >= nonEnglishConfidence
    }

    /// Lowercased lemmas of the words in `text` (English tagger; unknown words yield nothing).
    static func lemmas(_ text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var result: Set<String> = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if let lemma = tag?.rawValue.lowercased(), !lemma.isEmpty { result.insert(lemma) }
            return true
        }
        return result
    }

    /// NaturalLanguage-assisted check, used after the phrase and word lists find nothing.
    static func isPersonalByLanguageAnalysis(_ text: String) -> Bool {
        if isConfidentlyNonEnglish(text) { return true }
        return !lemmas(text).isDisjoint(with: personalWords)
    }
}
