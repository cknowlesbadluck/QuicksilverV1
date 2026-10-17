import XCTest
@testable import ServicesAI

final class PersonalClassifierTests: XCTestCase {
    private struct FixedSimilarity: SentenceSimilarity {
        let distance: Double?
        func minimumDistance(from text: String, to candidates: [String]) -> Double? { distance }
    }

    private struct FixedWords: WordSimilarity {
        let distance: Double?
        func minimumDistance(from words: Set<String>, toSeeds seeds: [String]) -> Double? { distance }
    }

    private let noWords = FixedWords(distance: nil)
    private let close = FixedSimilarity(distance: 0.4)
    private let far = FixedSimilarity(distance: 1.3)
    private let unavailable = FixedSimilarity(distance: nil)

    func testNoSelfReferenceIsImpersonalEvenWithoutEmbedding() {
        for text in ["How do I sort an array in Swift?", "What is the capital of Peru?", "Explain actors in Swift concurrency"] {
            XCTAssertEqual(PersonalClassifier.classify(text, similarity: unavailable, wordNeighbors: noWords), .impersonal, text)
            XCTAssertEqual(PersonalClassifier.classify(text, similarity: close, wordNeighbors: noWords), .impersonal, text)
        }
    }

    func testSelfReferenceFailsClosedWhenUndecided() {
        XCTAssertEqual(
            PersonalClassifier.classify("Can you help me plan the weekend", similarity: unavailable, wordNeighbors: noWords),
            .personal(.undecidedFailClosed)
        )
    }

    func testSelfReferenceUsesSemanticDistance() {
        let text = "Things have been rough for me lately"
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: close, wordNeighbors: noWords), .personal(.semantic))
        XCTAssertEqual(PersonalClassifier.classify("Rewrite my Swift function to be async", similarity: far, wordNeighbors: noWords), .impersonal)
    }

    func testThresholdBoundary() {
        let text = "my plan for tomorrow"
        let atThreshold = FixedSimilarity(distance: PersonalClassifier.semanticThreshold)
        let justAbove = FixedSimilarity(distance: PersonalClassifier.semanticThreshold + 0.01)
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: atThreshold, wordNeighbors: noWords), .personal(.semantic))
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: justAbove, wordNeighbors: noWords), .impersonal)
    }

    func testSelfReferenceWordsAreWholeTokens() {
        // "mystery", "museum", "use" must not count as "my", "mu", "us".
        XCTAssertEqual(PersonalClassifier.classify("Recommend a mystery novel to use at the museum", similarity: unavailable, wordNeighbors: noWords), .impersonal)
    }

    func testDomainWordWithSelfReferenceIsPersonal() {
        for text in ["my rent went up again", "our landlord won't fix the heating", "my knee still hurts"] {
            XCTAssertEqual(PersonalClassifier.classify(text, similarity: far, wordNeighbors: noWords), .personal(.domain), text)
        }
        // Without self-reference the same words are impersonal ("rent a car").
        XCTAssertEqual(PersonalClassifier.classify("How do I rent a car in Lisbon", similarity: far, wordNeighbors: noWords), .impersonal)
    }

    func testWordNeighbourLayer() {
        let near = FixedWords(distance: PersonalClassifier.wordNeighborThreshold)
        let text = "Things have been rough for me lately"
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: far, wordNeighbors: near), .personal(.domainNeighbor))
        // One embedding available and far on both: decided impersonal, not fail-closed.
        let farWords = FixedWords(distance: 1.5)
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: unavailable, wordNeighbors: farWords), .impersonal)
    }

    /// Real NaturalLanguage path: must never crash, and the knowledge question stays impersonal.
    func testRealEmbeddingPathIsSafe() {
        XCTAssertFalse(PersonalClassifier.isPersonal("What is the boiling point of water?"))
        _ = PersonalClassifier.classify("I have been worried about my blood pressure readings")
    }

    /// Wired into the gate: an undecided self-referential turn stays on device via the classifier,
    /// while English knowledge questions are unaffected.
    func testGateStillLetsKnowledgeQuestionsThrough() {
        XCTAssertFalse(CloudContextPolicy.isPersonalText("What is the speed of light in a vacuum?"))
        XCTAssertFalse(CloudContextPolicy.isPersonalText("How do I reverse a linked list?"))
    }
}
