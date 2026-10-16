import XCTest
@testable import ServicesAI

final class PersonalClassifierTests: XCTestCase {
    private struct FixedSimilarity: SentenceSimilarity {
        let distance: Double?
        func minimumDistance(from text: String, to candidates: [String]) -> Double? { distance }
    }

    private let close = FixedSimilarity(distance: 0.4)
    private let far = FixedSimilarity(distance: 1.3)
    private let unavailable = FixedSimilarity(distance: nil)

    func testNoSelfReferenceIsImpersonalEvenWithoutEmbedding() {
        for text in ["How do I sort an array in Swift?", "What is the capital of Peru?", "Explain actors in Swift concurrency"] {
            XCTAssertEqual(PersonalClassifier.classify(text, similarity: unavailable), .impersonal, text)
            XCTAssertEqual(PersonalClassifier.classify(text, similarity: close), .impersonal, text)
        }
    }

    func testSelfReferenceFailsClosedWhenUndecided() {
        XCTAssertEqual(
            PersonalClassifier.classify("Can you help me plan the weekend", similarity: unavailable),
            .personal(.undecidedFailClosed)
        )
    }

    func testSelfReferenceUsesSemanticDistance() {
        let text = "Things have been rough with my partner lately"
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: close), .personal(.semantic))
        XCTAssertEqual(PersonalClassifier.classify("Rewrite my Swift function to be async", similarity: far), .impersonal)
    }

    func testThresholdBoundary() {
        let text = "my plan for tomorrow"
        let atThreshold = FixedSimilarity(distance: PersonalClassifier.semanticThreshold)
        let justAbove = FixedSimilarity(distance: PersonalClassifier.semanticThreshold + 0.01)
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: atThreshold), .personal(.semantic))
        XCTAssertEqual(PersonalClassifier.classify(text, similarity: justAbove), .impersonal)
    }

    func testSelfReferenceWordsAreWholeTokens() {
        // "mystery", "museum", "use" must not count as "my", "mu", "us".
        XCTAssertEqual(PersonalClassifier.classify("Recommend a mystery novel to use at the museum", similarity: unavailable), .impersonal)
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
