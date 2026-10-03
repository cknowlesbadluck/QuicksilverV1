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

    @Test func midStreamErrorIsValidFailure() throws {
        let events = try GatewayWireDecoder.decodeSSE(try fixtureText("mid-stream-error.sse"))
        #expect(events == [
            .meta(route: "cloud", model: "fake", trainsOnPrompts: true),
            .delta("partial"),
            .error(code: .upstreamUnavailable, retryAfter: nil)
        ])
    }

    @Test func rateLimitWithoutRetryAfterIsRejected() {
        let body = "event: error\ndata: {\"code\":\"rate_limited\"}\n\n"
        #expect(throws: GatewayWireDecodeError.missingField("error.retryAfter")) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    @Test func crlfLineEndingsDecode() throws {
        let body = "event: error\r\ndata: {\"code\":\"timeout\"}\r\n\r\n"
        let events = try GatewayWireDecoder.decodeSSE(body)
        #expect(events == [.error(code: .timeout, retryAfter: nil)])
    }

    @Test func incompleteStreamWithoutTerminalIsRejected() {
        let body = """
        event: meta
        data: {"route":"on-device","model":"fake","trainsOnPrompts":false}

        event: delta
        data: {"text":"hi"}

        """
        #expect(throws: GatewayWireDecodeError.incompleteStream) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    @Test func unterminatedFinalEventAtEOFIsDiscarded() {
        // Pending fields without a blank line before EOF must not dispatch (WHATWG).
        let body = "event: error\ndata: {\"code\":\"timeout\"}\n"
        #expect(throws: GatewayWireDecodeError.empty) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    @Test func fractionalRetryAfterIsRejected() {
        let body = "event: error\ndata: {\"code\":\"rate_limited\",\"retryAfter\":2.9}\n\n"
        #expect(throws: GatewayWireDecodeError.missingField("error.retryAfter")) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    /// Blank line before EOF is required or the decoder discards the pending event.
    private func terminated(_ body: String) -> String {
        body.hasSuffix("\n\n") ? body : body + "\n\n"
    }

    @Test func fractionalUsageTokensAreRejected() {
        let body = terminated("""
        event: meta
        data: {"route":"on-device","model":"fake","trainsOnPrompts":false}

        event: done
        data: {"usage":{"promptTokens":1.5,"completionTokens":2}}
        """)
        #expect(throws: GatewayWireDecodeError.missingField("done.usage")) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    @Test func malformedUsageShapeIsRejected() {
        let body = terminated("""
        event: meta
        data: {"route":"on-device","model":"fake","trainsOnPrompts":false}

        event: done
        data: {"usage":null}
        """)
        #expect(throws: GatewayWireDecodeError.missingField("done.usage")) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    @Test func intMaxBoundaryIsAccepted() throws {
        let body = terminated("""
        event: meta
        data: {"route":"on-device","model":"fake","trainsOnPrompts":false}

        event: done
        data: {"usage":{"promptTokens":\(Int.max),"completionTokens":0}}
        """)
        let events = try GatewayWireDecoder.decodeSSE(body)
        #expect(events == [
            .meta(route: "on-device", model: "fake", trainsOnPrompts: false),
            .done(usage: AIResponse.Usage(promptTokens: Int.max, completionTokens: 0))
        ])
    }

    @Test func intOverflowIsRejected() {
        // One past Int.max — must not trap via Double round-trip.
        let body = terminated("""
        event: meta
        data: {"route":"on-device","model":"fake","trainsOnPrompts":false}

        event: done
        data: {"usage":{"promptTokens":9223372036854775808,"completionTokens":0}}
        """)
        #expect(throws: GatewayWireDecodeError.missingField("done.usage")) {
            try GatewayWireDecoder.decodeSSE(body)
        }
    }

    @Test func anyQueryStringIsRejected() {
        #expect(GatewayWireDecoder.rejectTokenInURL("https://gateway.example/v1/chat?token=secret"))
        #expect(GatewayWireDecoder.rejectTokenInURL("https://gateway.example/v1/chat?auth=secret"))
        #expect(GatewayWireDecoder.rejectTokenInURL("https://gateway.example/v1/chat?foo=bar"))
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

    /// `#filePath` lookup works for both SPM and the Xcode QuicksilverTests target (no Bundle.module).
    private func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/gateway/\(name)")
        return try Data(contentsOf: url)
    }

    private func fixtureText(_ name: String) throws -> String {
        String(decoding: try fixture(name), as: UTF8.self)
    }
}
