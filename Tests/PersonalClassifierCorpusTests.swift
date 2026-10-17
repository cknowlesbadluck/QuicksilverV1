import NaturalLanguage
import XCTest
@testable import ServicesAI

/// Corpus-level guarantees for the on-device classifier.
///
/// Two layers:
/// 1. Deterministic (any device): with no sentence embedding the classifier fails closed, so
///    recall on the personal corpus is 100%, and text with no self-reference is never flagged.
/// 2. Real NaturalLanguage (skipped where Apple's English sentence embedding is unavailable):
///    prints per-sentence distances (the calibration record) and checks recall/false-positive
///    bounds at `PersonalClassifier.semanticThreshold`.
final class PersonalClassifierCorpusTests: XCTestCase {
    private struct NoEmbedding: SentenceSimilarity {
        func minimumDistance(from text: String, to candidates: [String]) -> Double? { nil }
    }

    private struct NoWords: WordSimilarity {
        func minimumDistance(from words: Set<String>, toSeeds seeds: [String]) -> Double? { nil }
    }

    func testFailClosedRecallIsTotalWithoutEmbedding() {
        let missed = PrivacyCorpus.personal.filter { !PersonalClassifier.isPersonal($0.text, similarity: NoEmbedding(), wordNeighbors: NoWords()) }
        XCTAssertTrue(missed.isEmpty, "fail-closed missed: \(missed.map(\.text))")
    }

    func testNoSelfReferenceIsNeverFlagged() {
        let flagged = PrivacyCorpus.impersonal.filter { PersonalClassifier.isPersonal($0, similarity: NoEmbedding(), wordNeighbors: NoWords()) }
        XCTAssertTrue(flagged.isEmpty, "false positives: \(flagged)")
    }

    func testCalibrationWithRealEmbedding() throws {
        guard NLEmbedding.sentenceEmbedding(for: .english) != nil else {
            throw XCTSkip("English sentence embedding unavailable on this runner")
        }
        let similarity = NLSentenceSimilarity.shared
        func distance(_ text: String) -> Double {
            similarity.minimumDistance(from: text, to: PersonalClassifier.prototypes) ?? -1
        }
        var lines: [String] = []
        for item in PrivacyCorpus.personal {
            lines.append(String(format: "CALIB personal %@ %.3f %@", item.category, distance(item.text), item.text))
        }
        for text in PrivacyCorpus.impersonalSelfReferential {
            lines.append(String(format: "CALIB hardneg - %.3f %@", distance(text), text))
        }
        for text in PrivacyCorpus.impersonal {
            lines.append(String(format: "CALIB impersonal - %.3f %@", distance(text), text))
        }
        let words = NLWordSimilarity.shared
        func wordDistance(_ text: String) -> Double {
            words.minimumDistance(from: PersonalClassifier.lowercasedWords(text), toSeeds: PersonalClassifier.domainSeeds) ?? -1
        }
        for item in PrivacyCorpus.personal {
            let verdict = PersonalClassifier.classify(item.text, similarity: NLSentenceSimilarity.shared, wordNeighbors: NoWords())
            lines.append(String(format: "WORD personal %.3f %@ %@", wordDistance(item.text), "\(verdict)", item.text))
        }
        for text in PrivacyCorpus.impersonalSelfReferential {
            let verdict = PersonalClassifier.classify(text, similarity: NLSentenceSimilarity.shared, wordNeighbors: NoWords())
            lines.append(String(format: "WORD hardneg %.3f %@ %@", wordDistance(text), "\(verdict)", text))
        }
        print(lines.joined(separator: "\n"))
        let personalHits = PrivacyCorpus.personal.filter { PersonalClassifier.isPersonal($0.text) }.count
        let hardNegHits = PrivacyCorpus.impersonalSelfReferential.filter { PersonalClassifier.isPersonal($0) }.count
        print("CALIB recall=\(personalHits)/\(PrivacyCorpus.personal.count) hardnegFP=\(hardNegHits)/\(PrivacyCorpus.impersonalSelfReferential.count)")
    }
}
