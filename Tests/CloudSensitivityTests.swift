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

    func testShortNumbersAreNotIdentifiers() {
        for text in ["what happened in 1969", "open port 5988", "issue #1988 and 2026-10-14"] {
            XCTAssertFalse(CloudContextPolicy.isPersonalText(text), text)
        }
    }

    func testRequestLevelSignals() {
        XCTAssertTrue(CloudContextPolicy.isPersonal(AIRequest(prompt: "ok", metadata: [CloudContextPolicy.personalTurnKey: "1"])))
        let memory = GatewayContextBlock(kind: .memory, text: "likes tea", privacy: .cloud)
        XCTAssertTrue(CloudContextPolicy.isPersonal(AIRequest(prompt: "ok", context: [memory])))
        XCTAssertFalse(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "my doctor said rest")))
        XCTAssertTrue(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "explain recursion")))
    }

    func testAnyOutboundHistoryMessageMarksTurnPersonal() {
        let history = [Message(role: .assistant, content: "Your therapist note says rest.")]
        XCTAssertTrue(CloudContextPolicy.isPersonal(AIRequest(prompt: "explain recursion", history: history)))
    }

    func testCurrentPromptEchoedAsMemoryIsNotPersonal() {
        let echo = GatewayContextBlock(kind: .memory, text: "explain recursion", privacy: .cloud)
        XCTAssertTrue(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "Explain recursion", context: [echo])))
    }

    func testCoarseDeviceBlockAloneIsNotPersonal() {
        let device = GatewayContextBlock(kind: .device, text: "thermal nominal", privacy: .cloud)
        XCTAssertTrue(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: "explain recursion", context: [device])))
    }

    func testEmailAndCredentialDisclosuresStayLocal() {
        for text in [
            "my email is alice@example.com",
            "API token: abcdefghijklmnopqrstuvwxyz",
            "use API key sk-abc123def456",
            "here it is ghp_9f8e7d6c5b4a3f2e1d0c9b8a7f6e",
            "call me at 415-555-1212",
            "it's +44 20 7946 0958",
            "number 123-45-6789",
            "use ghp_9f8e7d6c5b4a3f2e1d0c9b8a7f6e, please",
            "DOB: 1990-01-01"
        ] {
            XCTAssertFalse(CloudContextPolicy.allowsCloudFallback(AIRequest(prompt: text)), text)
        }
    }
}
