import XCTest
@testable import Core
@testable import ServicesAI

/// Privacy gate: cheap local sensitivity check for cloud fallback.
final class CloudSensitivityTests: XCTestCase {
    func testPersonalCategoriesAreDetected() {
        let personal = [
            "I've been so depressed lately",          // distress
            "is this rash a symptom of something",    // health
            "what do you know about me",              // memory
            "text my wife that I'm late",             // contacts
            "where am I right now",                   // location
            "can I afford the mortgage on my salary", // finance
            "what’s my password for the router"       // credentials (curly apostrophe)
        ]
        for text in personal {
            XCTAssertTrue(CloudContextPolicy.isPersonalText(text), text)
        }
    }

    func testGeneralKnowledgeIsNotPersonal() {
        let general = [
            "explain how a binary search works",
            "plan the shelf",
            "what's the capital of Portugal",
            "write a haiku about rain",
            "summarize the system health diagnostics"
        ]
        for text in general {
            XCTAssertFalse(CloudContextPolicy.isPersonalText(text), text)
        }
    }

    func testRequestLevelSignals() {
        XCTAssertTrue(CloudContextPolicy.isPersonal(AIRequest(prompt: "ok", metadata: [CloudContextPolicy.personalTurnKey: "1"])))
        let device = GatewayContextBlock(kind: .device, text: "battery ok", privacy: .cloud)
        XCTAssertTrue(CloudContextPolicy.isPersonal(AIRequest(prompt: "ok", context: [device])))
        XCTAssertFalse(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "my doctor said rest")))
        XCTAssertTrue(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "explain recursion")))
    }

    func testAssistantHistoryDoesNotMarkTurnPersonal() {
        let history = [Message(role: .assistant, content: "Have you seen a doctor?")]
        XCTAssertFalse(CloudContextPolicy.isPersonal(AIRequest(prompt: "explain recursion", history: history)))
    }
}
