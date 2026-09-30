import XCTest
@testable import Core
@testable import ServicesAI

final class ProviderHTTPTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handlerBox.set(nil)
        super.tearDown()
    }

    func testGeminiHTTPContractAndSuccessDecode() async throws {
        let session = makeSession()
        URLProtocolStub.handlerBox.set { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.host, "generativelanguage.googleapis.com")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "gemini-test-key")
            XCTAssertNil(request.url?.query)

            let body = try XCTUnwrap(request.httpBody)
            let bodyText = try XCTUnwrap(String(data: body, encoding: .utf8))
            XCTAssertTrue(bodyText.contains("Mercury system"))
            XCTAssertTrue(bodyText.contains("Hello Gemini"))
            XCTAssertTrue(bodyText.contains("gemini-3.7-flash") == false)

            return try Self.httpResponse(
                for: request,
                status: 200,
                json: """
                {
                  "candidates": [
                    {
                      "content": {"parts": [{"text": "Gemini reply"}]},
                      "finishReason": "STOP"
                    }
                  ],
                  "usageMetadata": {
                    "promptTokenCount": 4,
                    "candidatesTokenCount": 2
                  }
                }
                """
            )
        }

        let provider = try GeminiAIProvider(apiKey: "gemini-test-key", session: session)
        let request = AIRequest(prompt: "Hello Gemini", systemPrompt: "Mercury system")
        let response = try await provider.complete(request)

        XCTAssertEqual(response.requestID, request.id)
        XCTAssertEqual(response.content, "Gemini reply")
        XCTAssertEqual(response.finishReason, .stop)
        XCTAssertEqual(response.usage?.promptTokens, 4)
        XCTAssertEqual(response.usage?.completionTokens, 2)
    }

    func testGrokHTTPContractAndSuccessDecode() async throws {
        let session = makeSession()
        URLProtocolStub.handlerBox.set { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.x.ai/v1/chat/completions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer grok-test-key")

            let body = try XCTUnwrap(request.httpBody)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["model"] as? String, "grok-4.6")
            XCTAssertEqual(object["max_tokens"] as? Int, 321)
            XCTAssertEqual(object["stream"] as? Bool, false)

            return try Self.httpResponse(
                for: request,
                status: 200,
                json: """
                {
                  "id": "response-1",
                  "choices": [
                    {
                      "message": {"role": "assistant", "content": "Grok reply"},
                      "finish_reason": "stop"
                    }
                  ],
                  "usage": {
                    "prompt_tokens": 5,
                    "completion_tokens": 3,
                    "total_tokens": 8
                  }
                }
                """
            )
        }

        let provider = try GrokAIProvider(apiKey: "grok-test-key", session: session)
        let request = AIRequest(prompt: "Hello Grok", systemPrompt: "Mercury system", maxTokens: 321)
        let response = try await provider.complete(request)

        XCTAssertEqual(response.requestID, request.id)
        XCTAssertEqual(response.content, "Grok reply")
        XCTAssertEqual(response.finishReason, .stop)
        XCTAssertEqual(response.usage?.promptTokens, 5)
        XCTAssertEqual(response.usage?.completionTokens, 3)
    }

    func testProviderStatusCodesMapToActionableErrors() async throws {
        let session = makeSession()
        let provider = try GeminiAIProvider(apiKey: "gemini-test-key", session: session)
        let request = AIRequest(prompt: "Status mapping")

        URLProtocolStub.handlerBox.set { request in
            try Self.httpResponse(for: request, status: 401, json: "{}")
        }
        do {
            _ = try await provider.complete(request)
            XCTFail("Expected rejected-key error")
        } catch let error as AppError {
            guard case .aiKeyRejected(let providerName) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(providerName, "Gemini")
        }

        URLProtocolStub.handlerBox.set { request in
            try Self.httpResponse(for: request, status: 429, json: "{}")
        }
        do {
            _ = try await provider.complete(request)
            XCTFail("Expected rate-limit error")
        } catch let error as AppError {
            guard case .aiRateLimited(let providerName) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(providerName, "Gemini")
        }

        URLProtocolStub.handlerBox.set { request in
            try Self.httpResponse(for: request, status: 500, json: "{}")
        }
        do {
            _ = try await provider.complete(request)
            XCTFail("Expected provider failure")
        } catch let error as AppError {
            guard case .aiRequestFailed = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testMalformedProviderJSONIsRejected() async throws {
        let session = makeSession()
        URLProtocolStub.handlerBox.set { request in
            try Self.httpResponse(for: request, status: 200, json: "{not-json")
        }

        let provider = try GrokAIProvider(apiKey: "grok-test-key", session: session)
        do {
            _ = try await provider.complete(AIRequest(prompt: "Decode this"))
            XCTFail("Expected decode failure")
        } catch let error as AppError {
            guard case .aiRequestFailed = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func httpResponse(
        for request: URLRequest,
        status: Int,
        json: String
    ) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (response, Data(json.utf8))
    }
}

private final class URLProtocolStub: URLProtocol {
    final class HandlerBox: @unchecked Sendable {
        typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

        private let lock = NSLock()
        private var handler: Handler?

        func set(_ newHandler: Handler?) {
            lock.lock()
            handler = newHandler
            lock.unlock()
        }

        func get() -> Handler? {
            lock.lock()
            defer { lock.unlock() }
            return handler
        }
    }

    static let handlerBox = HandlerBox()

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handlerBox.get() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
