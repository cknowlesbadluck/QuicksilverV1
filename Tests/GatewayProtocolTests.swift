import Foundation
import Testing
@testable import Core

@Suite("Gateway protocol v1")
struct GatewayProtocolTests {
    @Test func chatRequestFixtureRoundTrips() throws {
        let data = try fixture("chat-request.json")
        let request = try GatewayWireDecoder.decodeRequest(data)
        #expect(request.taskTier == "standard")
        #expect(request.messages.count == 1)
        #expect(request.context.map(\.kind) == [.memory, .device])
        #expect(request.privacy == .device)
        #expect(request.maxTokens == 64)
    }

    @Test func happyStreamIsMetaDeltaDone() throws {
        let events = try GatewayWireDecoder.decodeSSE(try fixtureText("happy.sse"))
        #expect(events == [
            .meta(route: "on-device", model: "fake", trainsOnPrompts: false),
            .delta("Forge"),
            .done(usage: AIResponse.Usage(promptTokens: 12, completionTokens: 1))
        ])
    }

    @Test func everyErrorFixtureDecodes() throws {
        let expected: [(String, GatewayErrorCode, Int?)] = [
            ("unauthorized.sse", .unauthorized, nil),
            ("rate-limited.sse", .rateLimited, 2),
            ("budget-exhausted.sse", .budgetExhausted, nil),
            ("upstream-unavailable.sse", .upstreamUnavailable, nil),
            ("bad-request.sse", .badRequest, nil),
            ("timeout.sse", .timeout, nil)
        ]
        for row in expected {
            let events = try GatewayWireDecoder.decodeSSE(try fixtureText(row.0))
            #expect(events == [.error(code: row.1, retryAfter: row.2)])
        }
    }

    @Test func rateLimitWithoutRetryAfterIsRejected() {
        let body = "event: error\ndata: {\"code\":\"rate_limited\"}\n"
        #expect(throws: GatewayWireDecodeError.missingField("error.retryAfter")) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    @Test func tokenInURLIsRejected() {
        #expect(GatewayWireDecoder.rejectTokenInURL("https://gateway.example/v1/chat?token=secret"))
        #expect(GatewayWireDecoder.rejectTokenInURL("https://user:secret@gateway.example/v1/chat"))
        #expect(GatewayWireDecoder.rejectTokenInURL("https://gateway.example/v1/chat#access_token=secret"))
        #expect(!GatewayWireDecoder.rejectTokenInURL("https://gateway.example/v1/chat"))
    }

    @Test func healthAndConfigFixturesAreV1() throws {
        let health = try JSONSerialization.jsonObject(with: fixture("health.json")) as? [String: Any]
        #expect(health?["service"] as? String == "mercury-gateway")
        let config = try JSONSerialization.jsonObject(with: fixture("config.json")) as? [String: Any]
        #expect(config?["protocol"] as? String == "v1")
    }

    private func fixture(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "gateway")
            ?? Bundle.module.url(forResource: name, withExtension: nil)
        return try Data(contentsOf: try #require(url))
    }

    private func fixtureText(_ name: String) throws -> String {
        String(decoding: try fixture(name), as: UTF8.self)
    }
}
