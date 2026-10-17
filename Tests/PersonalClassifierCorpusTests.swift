import NaturalLanguage
import XCTest
@testable import Core
@testable import ServicesAI

/// Corpus-level guarantees for the on-device "is this personal?" classifier.
///
/// Calibration record (macOS CI runner, Apple English sentence embedding, 2026-10-17):
/// - Sentence-embedding distance to the prototypes does not separate the classes: personal
///   0.90–1.23, hard negatives 0.93–1.16. At `semanticThreshold` 0.85 it flags none of either,
///   so it stays as a zero-false-positive backstop, not the main signal.
/// - A word-embedding neighbour layer was probed and dropped: per-word distances to domain seeds
///   overlapped the same way (personal 0.88–1.12, hard negatives 1.04–1.16).
/// - What separates is self-reference plus a personal-domain lemma, which is why `domainLemmas`
///   exists. Tuning corpus: recall 19/20, hard-negative false positives 0/10.
final class PersonalClassifierCorpusTests: XCTestCase {
    private struct NoEmbedding: SentenceSimilarity {
        func minimumDistance(from text: String, to candidates: [String]) -> Double? { nil }
    }

    private func rate(_ texts: [String], _ isPersonal: (String) -> Bool) -> Double {
        Double(texts.filter(isPersonal).count) / Double(texts.count)
    }

    // MARK: Deterministic (any device)

    /// No embedding: every self-referential turn fails closed, so recall is 100% on both sets.
    func testFailClosedRecallIsTotalWithoutEmbedding() {
        let all = PrivacyCorpus.personal.map(\.text) + PrivacyCorpus.heldOutPersonal
        let missed = all.filter { !PersonalClassifier.isPersonal($0, similarity: NoEmbedding()) }
        XCTAssertTrue(missed.isEmpty, "fail-closed missed: \(missed)")
    }

    /// Text with no self-reference is never flagged, embedding or not (precision on knowledge questions).
    func testNoSelfReferenceIsNeverFlagged() {
        let flagged = PrivacyCorpus.impersonal.filter {
            PersonalClassifier.isPersonal($0, similarity: NoEmbedding()) || PersonalClassifier.isPersonal($0)
        }
        XCTAssertTrue(flagged.isEmpty, "false positives: \(flagged)")
    }

    /// Lexicon layer alone (embedding answers "far"): tuning-corpus recall and hard-negative precision.
    func testDomainLexiconOnTuningCorpus() {
        struct Far: SentenceSimilarity {
            func minimumDistance(from text: String, to candidates: [String]) -> Double? { 1.5 }
        }
        let recall = rate(PrivacyCorpus.personal.map(\.text)) { PersonalClassifier.isPersonal($0, similarity: Far()) }
        let falsePositive = rate(PrivacyCorpus.impersonalSelfReferential) { PersonalClassifier.isPersonal($0, similarity: Far()) }
        XCTAssertGreaterThanOrEqual(recall, 0.95)
        XCTAssertEqual(falsePositive, 0)
    }

    /// Every category in the tuning corpus is represented and caught by at least one rule.
    func testEveryCategoryIsCovered() {
        struct Far: SentenceSimilarity {
            func minimumDistance(from text: String, to candidates: [String]) -> Double? { 1.5 }
        }
        let categories = Dictionary(grouping: PrivacyCorpus.personal, by: \.category)
        XCTAssertEqual(Set(categories.keys), ["names", "health", "finance", "location", "contacts", "relationships", "emotions", "work"])
        for (category, items) in categories {
            XCTAssertTrue(items.contains { PersonalClassifier.isPersonal($0.text, similarity: Far()) }, category)
        }
    }

    // MARK: Held out, with the real NaturalLanguage stack

    func testHeldOutGeneralisation() throws {
        guard NLEmbedding.sentenceEmbedding(for: .english) != nil else {
            throw XCTSkip("English sentence embedding unavailable on this runner")
        }
        let recall = rate(PrivacyCorpus.heldOutPersonal) { PersonalClassifier.isPersonal($0) }
        let falsePositive = rate(PrivacyCorpus.heldOutImpersonalSelfReferential) { PersonalClassifier.isPersonal($0) }
        print("HELDOUT recall=\(recall) fp=\(falsePositive)")
        for text in PrivacyCorpus.heldOutPersonal + PrivacyCorpus.heldOutImpersonalSelfReferential {
            print("HELDOUT \(PersonalClassifier.classify(text)) | \(text)")
        }
        XCTAssertGreaterThanOrEqual(recall, 0.5, "held-out recall regressed")
        XCTAssertLessThanOrEqual(falsePositive, 0.2, "held-out false positives regressed")
    }

    // MARK: Where the classifier matters in routing

    /// The planner already keeps first-person prompts local; the classifier's job is the history.
    /// An impersonal follow-up after a personal turn must not become cloud-eligible.
    func testPersonalHistoryKeepsImpersonalFollowUpLocal() {
        for personal in ["my rent went up again", "my knee has been swollen since sunday", "my dad hasn't called me"] {
            let request = AIRequest(
                prompt: "What is the capital of Peru?",
                history: [Message(role: .user, content: personal), Message(role: .assistant, content: "I'm sorry.")]
            )
            XCTAssertEqual(CloudContextPolicy.plan(request), .localOnly(reason: "personal"), personal)
        }
        // Without an embedding the coding history fails closed (local); with one it is cloud-eligible.
        guard NLEmbedding.sentenceEmbedding(for: .english) != nil else { return }
        let clean = AIRequest(
            prompt: "What is the capital of Peru?",
            history: [Message(role: .user, content: "Rewrite my Swift function to use async await")]
        )
        XCTAssertEqual(CloudContextPolicy.plan(clean), .cloudEligible)
    }
}
