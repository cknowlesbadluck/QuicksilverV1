import XCTest
@testable import ServicesAI
@testable import Core

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var errorHandler: ((URLRequest) throws -> Error)?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        if let errorHandler = MockURLProtocol.errorHandler {
            do {
                let error = try errorHandler(request)
                client?.urlProtocol(self, didFailWithError: error)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }

        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
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

final class GrokAPIModelsTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.errorHandler = nil
        super.tearDown()
    }

    func testChatResponseDecoding() throws {
        let json = """
        {
          "id": "chatcmpl-test",
          "choices": [{"message": {"role": "assistant", "content": "Forge ready."}, "finish_reason": "stop"}],
          "usage": {"prompt_tokens": 12, "completion_tokens": 4, "total_tokens": 16}
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(GrokAPI.ChatResponse.self, from: json)
        XCTAssertEqual(decoded.choices.count, 1)
        XCTAssertEqual(decoded.choices[0].message.content, "Forge ready.")
        XCTAssertEqual(decoded.usage?.prompt_tokens, 12)
    }

    func testGrokMakeFactory() {
        XCTAssertNil(GrokAIProvider.make(apiKey: ""))
        XCTAssertNotNil(GrokAIProvider.make(apiKey: "xai-test"))
    }

    func testGrokNetworkErrorHandling() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.errorHandler = { _ in
            struct TestError: Error {}
            return TestError()
        }

        let provider = try GrokAIProvider(apiKey: "test-key", session: session)
        let request = AIRequest(prompt: "Hello")

        do {
            _ = try await provider.complete(request)
            XCTFail("Expected complete() to throw networkUnavailable")
        } catch AppError.networkUnavailable {
            // Expected
        } catch {
            XCTFail("Expected AppError.networkUnavailable, but got unexpected error \(error)")
        }
    }

    func testGrokHTTPErrorHandling() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let provider = try GrokAIProvider(apiKey: "test-key", session: session)
        let request = AIRequest(prompt: "Hello")

        do {
            _ = try await provider.complete(request)
            XCTFail("Expected complete() to throw aiRequestFailed")
        } catch AppError.aiRequestFailed(let msg) {
            XCTAssertTrue(msg.contains("HTTP 500"))
        } catch {
            XCTFail("Expected AppError.aiRequestFailed, but got unexpected error \(error)")
        }
    }
}
