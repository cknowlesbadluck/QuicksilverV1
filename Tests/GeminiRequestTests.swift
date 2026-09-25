import XCTest
@testable import Core
@testable import ServicesAI

/// M1-T13: the Gemini key travels in the `x-goog-api-key` header, never in the URL.
final class GeminiRequestTests: XCTestCase {

    private let secret = "test-secret-key-123"

    private func makeRequest() throws -> URLRequest {
        let provider = try GeminiAIProvider(apiKey: secret)
        return try provider.makeURLRequest(AIRequest(prompt: "Hello", systemPrompt: "You are Mercury."))
    }

    func testRequestURLHasNoKeyQueryItem() throws {
        let request = try makeRequest()
        let url = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertFalse(components.queryItems?.contains { $0.name == "key" } ?? false)
        XCTAssertNil(components.query)
        XCTAssertFalse(url.absoluteString.contains(secret))
    }

    func testAPIKeyHeaderIsSet() throws {
        let request = try makeRequest()
        XCTAssertEqual(GeminiAIProvider.apiKeyHeaderField, "x-goog-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), secret)
    }

    func testRequestShapeIsUnchanged() throws {
        let request = try makeRequest()
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.url?.host, "generativelanguage.googleapis.com")
        XCTAssertEqual(request.url?.path, "/v1beta/models/gemini-3.7-flash:generateContent")
        let body = try XCTUnwrap(request.httpBody)
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(text.contains("Hello"))
        XCTAssertFalse(text.contains(secret))
    }
}
