import Foundation
import XCTest
@testable import Core
@testable import ServicesAI

/// M3-T8: AIRequest history encodes as protocol v1 messages (system → history → user).
final class GatewayRequestTests: XCTestCase {

    func testMultiturnEncodingMatchesFixture() throws {
        let request = AIRequest(
            prompt: "Name one Forge strength.",
            systemPrompt: "You are Quicksilver.",
            history: [
                Message(role: .user, content: "What aspect is active?"),
                Message(role: .assistant, content: "Forge.")
            ],
            maxTokens: 128
        )
        let encoded = GatewayRequest.makeChatBody(request)
        let fixture = try GatewayWireDecoder.decodeRequest(try fixtureData("chat-request-multiturn.json"))
        XCTAssertEqual(encoded, fixture)
        XCTAssertEqual(encoded.messages.map(\.role), ["system", "user", "assistant", "user"])
        XCTAssertEqual(
            encoded.messages.map(\.content),
            [
                "You are Quicksilver.",
                "What aspect is active?",
                "Forge.",
                "Name one Forge strength."
            ]
        )
        XCTAssertEqual(encoded.taskTier, "standard")
        XCTAssertEqual(encoded.context, [])
        XCTAssertEqual(encoded.privacy, .device)
        XCTAssertEqual(encoded.maxTokens, 128)
    }

    func testEncodeChatBodyRoundTripsViaWireDecoder() throws {
        let request = AIRequest(
            prompt: "Name one Forge strength.",
            systemPrompt: "You are Quicksilver.",
            history: [
                Message(role: .user, content: "What aspect is active?"),
                Message(role: .assistant, content: "Forge.")
            ],
            maxTokens: 128
        )
        let data = try GatewayRequest.encodeChatBody(request)
        let decoded = try GatewayWireDecoder.decodeRequest(data)
        XCTAssertEqual(decoded, GatewayRequest.makeChatBody(request))
    }

    func testEmptyHistoryMatchesSingleTurnShape() throws {
        let request = AIRequest(
            prompt: "Hello",
            systemPrompt: "Be brief",
            maxTokens: 64
        )
        let body = GatewayRequest.makeChatBody(request)
        XCTAssertEqual(body.messages.map(\.role), ["system", "user"])
        XCTAssertEqual(body.messages.map(\.content), ["Be brief", "Hello"])
        XCTAssertEqual(body.context, [])
        XCTAssertEqual(body.privacy, .device)
        XCTAssertEqual(body.taskTier, "standard")
        XCTAssertEqual(body.maxTokens, 64)
    }

    func testEmptySystemPromptIsOmitted() throws {
        let request = AIRequest(
            prompt: "Ping",
            systemPrompt: "",
            history: [Message(role: .assistant, content: "Pong")]
        )
        let body = GatewayRequest.makeChatBody(request)
        XCTAssertEqual(body.messages.map(\.role), ["assistant", "user"])
        XCTAssertEqual(body.messages.map(\.content), ["Pong", "Ping"])
    }

    func testNilSystemPromptIsOmitted() throws {
        let request = AIRequest(prompt: "Only user")
        let body = GatewayRequest.makeChatBody(request)
        XCTAssertEqual(body.messages.map(\.role), ["user"])
        XCTAssertEqual(body.messages.map(\.content), ["Only user"])
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/gateway/\(name)")
        return try Data(contentsOf: url)
    }
}
