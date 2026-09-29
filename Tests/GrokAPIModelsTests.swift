import XCTest
@testable import ServicesAI
import Core

final class GrokAPIModelsTests: XCTestCase {
    func testChatResponseDecoding() throws {
        let json = Data("""
        {
          "id": "chatcmpl-test",
          "choices": [{"message": {"role": "assistant", "content": "Forge ready."}, "finish_reason": "stop"}],
          "usage": {"prompt_tokens": 12, "completion_tokens": 4, "total_tokens": 16}
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(GrokAPI.ChatResponse.self, from: json)
        XCTAssertEqual(decoded.choices.count, 1)
        XCTAssertEqual(decoded.choices[0].message.content, "Forge ready.")
        XCTAssertEqual(decoded.choices[0].finishReason, "stop")
        XCTAssertEqual(decoded.usage?.promptTokens, 12)
        XCTAssertEqual(decoded.usage?.completionTokens, 4)
        XCTAssertEqual(decoded.usage?.totalTokens, 16)
    }

    func testChatRequestEncodingUsesSnakeCaseKeys() throws {
        let body = GrokAPI.ChatRequest(
            model: "grok-4.6",
            messages: [GrokAPI.ChatMessage(role: "user", content: "hi")],
            temperature: 0.2,
            maxTokens: 128,
            stream: false
        )
        let data = try JSONEncoder().encode(body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["max_tokens"] as? Int, 128)
        XCTAssertNil(object["maxTokens"])
        XCTAssertEqual(object["model"] as? String, "grok-4.6")
        XCTAssertEqual(object["stream"] as? Bool, false)
    }

    func testChatResponseDecodesNullOrMissingContent() throws {
        let json = Data("""
        {
          "choices": [
            {"message": {"role": "assistant", "content": null}, "finish_reason": "stop"},
            {"message": {"role": "assistant"}, "finish_reason": "stop"}
          ]
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(GrokAPI.ChatResponse.self, from: json)
        XCTAssertEqual(decoded.choices.count, 2)
        XCTAssertNil(decoded.choices[0].message.content)
        XCTAssertNil(decoded.choices[1].message.content)
    }

    func testProviderHTTPErrorDistinguishesAuthAndRateLimit() {
        guard case .aiRequestFailed(let unauthorized) = ProviderHTTPError.error(provider: "Grok", status: 401),
              case .aiRequestFailed(let forbidden) = ProviderHTTPError.error(provider: "Grok", status: 403),
              case .aiRequestFailed(let limited) = ProviderHTTPError.error(provider: "Gemini", status: 429),
              case .aiRequestFailed(let server) = ProviderHTTPError.error(provider: "Gemini", status: 500) else {
            return XCTFail("expected aiRequestFailed")
        }
        XCTAssertTrue(unauthorized.contains("rejected the API key"))
        XCTAssertTrue(forbidden.contains("rejected the API key"))
        XCTAssertTrue(limited.contains("rate limit"))
        XCTAssertTrue(server.contains("HTTP 500"))
        XCTAssertNotEqual(unauthorized, limited)
    }

    func testGrokMakeFactory() {
        XCTAssertNil(GrokAIProvider.make(apiKey: ""))
        XCTAssertNotNil(GrokAIProvider.make(apiKey: "xai-test"))
    }
}
