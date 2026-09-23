import Foundation
import XCTest

#if canImport(Quicksilver)
@testable import Quicksilver
#else
@testable import Nexus
#endif

// swiftlint:disable:next static_over_final_class
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    @MainActor static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Task {
            guard let handler = await MainActor.run(body: { MockURLProtocol.requestHandler }) else {
                fatalError("Handler is unavailable.")
            }

            do {
                let (response, data) = try handler(self.request)
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

final class IntegrationPlaneClientTests: XCTestCase {

    var session: URLSession!
    var client: IntegrationPlaneClient!
    let endpoint = URL(string: "http://localhost:8080/mcp")!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        client = IntegrationPlaneClient(endpoint: endpoint, session: session)
    }

    override func tearDown() {
        Task { @MainActor in MockURLProtocol.requestHandler = nil }
        session = nil
        client = nil
        super.tearDown()
    }

    func testInitializeSuccess() async throws {
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let jsonString = """
            {
                "jsonrpc": "2.0",
                "id": 1,
                "result": {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {},
                    "serverInfo": { "name": "TestServer", "version": "1.0.0" }
                }
            }
            """
            return (response, jsonString.data(using: .utf8)!)
        } }

        try await client.initialize()
    }

    func testInitializeFailureInvalidResponse() async {
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        } }

        do {
            try await client.initialize()
            XCTFail("Should throw an error")
        } catch IntegrationPlaneClient.ClientError.invalidResponse {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInitializeFailureRemoteError() async {
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let jsonString = """
            {
                "jsonrpc": "2.0",
                "id": 1,
                "error": {
                    "code": -32600,
                    "message": "Invalid Request"
                }
            }
            """
            return (response, jsonString.data(using: .utf8)!)
        } }

        do {
            try await client.initialize()
            XCTFail("Should throw an error")
        } catch IntegrationPlaneClient.ClientError.remoteError(let msg) {
            XCTAssertEqual(msg, "Invalid Request")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testListToolsSuccess() async throws {
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let jsonString = """
            {
                "jsonrpc": "2.0",
                "id": 2,
                "result": {
                    "tools": [
                        { "name": "tool1", "description": "A tool" },
                        { "name": "tool2", "description": "Another tool" }
                    ]
                }
            }
            """
            return (response, jsonString.data(using: .utf8)!)
        } }

        let tools = try await client.listTools()
        XCTAssertEqual(tools.count, 2)
        XCTAssertEqual(tools[0]["name"], .string("tool1"))
        XCTAssertEqual(tools[1]["name"], .string("tool2"))
    }

    func testListToolsMalformedResult() async {
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let jsonString = """
            {
                "jsonrpc": "2.0",
                "id": 2,
                "result": {
                    "something_else": []
                }
            }
            """
            return (response, jsonString.data(using: .utf8)!)
        } }

        do {
            _ = try await client.listTools()
            XCTFail("Should throw an error")
        } catch IntegrationPlaneClient.ClientError.malformedToolResult {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCallToolSuccess() async throws {
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let jsonString = """
            {
                "jsonrpc": "2.0",
                "id": 3,
                "result": {
                    "content": [{
                        "type": "text",
                        "text": "Tool output"
                    }]
                }
            }
            """
            return (response, jsonString.data(using: .utf8)!)
        } }

        let result = try await client.callTool(name: "testTool", arguments: ["param": .string("value")])
        guard case let .object(obj) = result,
              case let .array(content) = obj["content"],
              let firstContent = content.first,
              case let .object(item) = firstContent,
              case let .string(text) = item["text"] else {
            XCTFail("Invalid result structure")
            return
        }

        XCTAssertEqual(text, "Tool output")
    }

    func testCallToolFailureRemoteError() async {
         await MainActor.run { MockURLProtocol.requestHandler = { request in
             let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
             let jsonString = """
             {
                 "jsonrpc": "2.0",
                 "id": 3,
                 "error": {
                     "code": -32602,
                     "message": "Invalid params"
                 }
             }
             """
             return (response, jsonString.data(using: .utf8)!)
         }

         do {
             _ = try await client.callTool(name: "testTool")
             XCTFail("Should throw an error")
         } catch IntegrationPlaneClient.ClientError.remoteError(let msg) {
             XCTAssertEqual(msg, "Invalid params")
         } catch {
             XCTFail("Unexpected error: \(error)")
         }
    }

    func testCallToolFailureMalformedResult() async {
         await MainActor.run { MockURLProtocol.requestHandler = { request in
             let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
             let jsonString = """
             {
                 "jsonrpc": "2.0",
                 "id": 3
             }
             """
             return (response, jsonString.data(using: .utf8)!)
         }

         do {
             _ = try await client.callTool(name: "testTool")
             XCTFail("Should throw an error")
         } catch IntegrationPlaneClient.ClientError.malformedToolResult {
             // Expected
         } catch {
             XCTFail("Unexpected error: \(error)")
         }
    }

    func testServerSentEventsResponse() async throws {
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let eventString = """
            event: message
            data: { "jsonrpc": "2.0", "id": 1, "result": { "protocolVersion": "2025-06-18" } }

            """
            return (response, eventString.data(using: .utf8)!)
        } }

        try await client.initialize()
    }

    func testSessionIdIsPreserved() async throws {
        var callCount = 0
        await MainActor.run { MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                 // First call sets the header
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Mcp-Session-Id": "sess-1234"]
                )!
                let jsonString = """
                {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "result": { "protocolVersion": "2025-06-18" }
                }
                """
                return (response, jsonString.data(using: .utf8)!)
            } else {
                // Second call should send the header
                XCTAssertEqual(request.value(forHTTPHeaderField: "Mcp-Session-Id"), "sess-1234")

                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let jsonString = """
                {
                    "jsonrpc": "2.0",
                    "id": 2,
                    "result": { "tools": [] }
                }
                """
                return (response, jsonString.data(using: .utf8)!)
            }
        }

        try await client.initialize()
        _ = try await client.listTools()
        XCTAssertEqual(callCount, 2)
    }
}
