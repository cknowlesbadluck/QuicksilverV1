import XCTest
@testable import Core
@testable import ServicesAI

/// M3.5-T19: deterministic needsCloud planner.
final class CloudPlannerTests: XCTestCase {
    func testImpersonalKnowledgeQuestionsAreCloudEligible() {
        for text in ["explain recursion", "What is the capital of Portugal?", "translate 'good morning' to French",
                     "plan the shelf", "how does TCP congestion control work"] {
            XCTAssertEqual(CloudContextPolicy.plan(AIRequest(prompt: text)), .cloudEligible, text)
        }
    }

    func testPersonalAndFirstPersonTurnsStayLocal() {
        XCTAssertEqual(CloudContextPolicy.plan(AIRequest(prompt: "what did my doctor say")), .localOnly(reason: "personal"))
        XCTAssertEqual(CloudContextPolicy.plan(AIRequest(prompt: "how do I fix this")), .localOnly(reason: "first-person"))
        XCTAssertEqual(CloudContextPolicy.plan(AIRequest(prompt: "we should go")), .localOnly(reason: "first-person"))
    }

    func testNonKnowledgeTurnsStayLocal() {
        XCTAssertEqual(CloudContextPolicy.plan(AIRequest(prompt: "lol ok")), .localOnly(reason: "not a knowledge question"))
        XCTAssertEqual(CloudContextPolicy.plan(AIRequest(prompt: "   ")), .localOnly(reason: "empty"))
    }

    func testPlanIsDeterministicAndGatesFallback() {
        let request = AIRequest(prompt: "Explain recursion")
        XCTAssertEqual(CloudContextPolicy.plan(request), CloudContextPolicy.plan(request))
        XCTAssertTrue(CloudContextPolicy.allowsCloudFallback(request))
        XCTAssertFalse(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "remind me later")))
    }
}
