import XCTest
@testable import Core
@testable import ServicesAI

/// Privacy gate + NaturalLanguage: inflections via lemmas, and non-English fails closed.
final class PrivacyGateLanguageTests: XCTestCase {
    func testInflectedPersonalWordsAreCaughtByLemma() {
        XCTAssertTrue(CloudContextPolicy.isPersonalText("which medications interact badly together"))
        XCTAssertTrue(CloudContextPolicy.isPersonalText("compare the nearest hospitals tonight"))
    }

    func testConfidentNonEnglishFailsClosed() {
        XCTAssertTrue(CloudContextPolicy.isPersonalText("¿Cuál es la capital de Francia y cuántos habitantes tiene?"))
        XCTAssertTrue(CloudContextPolicy.isPersonalText("Quelle est la meilleure façon de cuisiner des pâtes fraîches ?"))
        XCTAssertFalse(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "Wie hoch ist der höchste Berg der Welt eigentlich?")))
    }

    func testEnglishKnowledgeQuestionsStayImpersonal() {
        for prompt in [
            "what is the capital of france",
            "explain how photosynthesis works in plants",
            "how many moons does jupiter have",
            "write a haiku about autumn leaves falling"
        ] {
            XCTAssertFalse(CloudContextPolicy.isPersonalText(prompt), prompt)
        }
    }

    func testShortTextSkipsLanguageIdentification() {
        XCTAssertFalse(CloudContextPolicy.isConfidentlyNonEnglish("hola"))
    }
}
