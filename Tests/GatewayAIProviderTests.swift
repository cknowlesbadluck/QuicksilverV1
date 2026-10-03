import XCTest
@testable import Core
@testable import ServicesAI

final class GatewayAIProviderTests: XCTestCase {
    override func tearDown() {
        GatewayURLProtocolStub.reset()
        super.tearDown()
    }

    // MARK: - Happy path

    func testHappyPathStreamsMetaDeltaDone() async throws {
        let sse = try fixtureText("happy.sse")
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.assertAuthorizedChat(request)
            return try Self.sseResponse(for: request, status: 200, body: sse)
        }

        let provider = try makeProvider(session: session)
        var collected: [AIStreamEvent] = []
        for try await event in provider.stream(AIRequest(prompt: "Name the active aspect.", systemPrompt: "Be brief")) {
            collected.append(event)
        }

        XCTAssertEqual(collected, [
            .meta(route: "on-device", model: "fake", trainsOnPrompts: false),
            .delta("Forge"),
            .done(usage: AIResponse.Usage(promptTokens: 12, completionTokens: 1))
        ])
    }

    func testCompleteAggregatesStream() async throws {
        let sse = try fixtureText("happy.sse")
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            let body = try Self.bodyData(from: request)
            let decoded = try GatewayWireDecoder.decodeRequest(body)
            XCTAssertEqual(decoded.taskTier, "standard")
            XCTAssertEqual(decoded.privacy, .device)
            XCTAssertEqual(decoded.context, [])
            XCTAssertEqual(decoded.messages.map(\.role), ["system", "user"])
            XCTAssertEqual(decoded.messages.map(\.content), ["Be brief", "Hello"])
            return try Self.sseResponse(for: request, status: 200, body: sse)
        }

        let provider = try makeProvider(session: session)
        let response = try await provider.complete(
            AIRequest(prompt: "Hello", systemPrompt: "Be brief", maxTokens: 64)
        )
        XCTAssertEqual(response.content, "Forge")
        XCTAssertEqual(response.usage?.promptTokens, 12)
        XCTAssertEqual(response.usage?.completionTokens, 1)
    }

    // MARK: - Mid-stream error

    func testMidStreamErrorYieldsPartialThenThrows() async throws {
        let sse = try fixtureText("mid-stream-error.sse")
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.sseResponse(for: request, status: 200, body: sse)
        }

        let provider = try makeProvider(session: session)
        var collected: [AIStreamEvent] = []
        do {
            for try await event in provider.stream(AIRequest(prompt: "partial")) {
                collected.append(event)
            }
            XCTFail("Expected upstream failure")
        } catch let error as AppError {
            guard case .aiRequestFailed = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }

        XCTAssertEqual(collected, [
            .meta(route: "cloud", model: "fake", trainsOnPrompts: true),
            .delta("partial")
        ])
    }

    // MARK: - First-event timeout

    func testFirstEventTimeout() async throws {
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.sseResponse(for: request, status: 200, body: "", hang: true)
        }

        let provider = try makeProvider(
            session: session,
            timeouts: GatewayTimeouts(connect: 5, firstEvent: 0.15, idle: 5, total: 5)
        )

        let started = ContinuousClock.now
        do {
            for try await _ in provider.stream(AIRequest(prompt: "timeout")) {
                XCTFail("Should not receive events")
            }
            XCTFail("Expected first-event timeout")
        } catch let error as AppError {
            guard case .aiRequestFailed = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }
        let elapsed = started.duration(to: .now)
        XCTAssertLessThan(elapsed, Duration.seconds(2))
    }

    // MARK: - HTTP 401 / SSE unauthorized

    func testHTTP401MapsToUnauthorized() async throws {
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.sseResponse(for: request, status: 401, body: "{}")
        }

        let provider = try makeProvider(session: session)
        do {
            for try await _ in provider.stream(AIRequest(prompt: "nope")) {}
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            guard case .aiKeyRejected(let name) = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertEqual(name, "Gateway")
        }
    }

    func testUnauthorizedFixtureMapsToKeyRejected() async throws {
        let sse = try fixtureText("unauthorized.sse")
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.sseResponse(for: request, status: 200, body: sse)
        }

        let provider = try makeProvider(session: session)
        do {
            for try await _ in provider.stream(AIRequest(prompt: "nope")) {}
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            guard case .aiKeyRejected(let name) = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertEqual(name, "Gateway")
        }
    }

    // MARK: - 429 / rate limited

    func testRateLimitedFixtureMapsToRateLimited() async throws {
        let sse = try fixtureText("rate-limited.sse")
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.sseResponse(for: request, status: 200, body: sse)
        }

        let provider = try makeProvider(session: session)
        do {
            for try await _ in provider.stream(AIRequest(prompt: "slow down")) {}
            XCTFail("Expected rate limit")
        } catch let error as AppError {
            guard case .aiRateLimited(let name) = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertEqual(name, "Gateway")
        }
    }

    func testHTTP429MapsToRateLimited() async throws {
        let session = makeSession()
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.sseResponse(for: request, status: 429, body: "{}")
        }

        let provider = try makeProvider(session: session)
        do {
            for try await _ in provider.stream(AIRequest(prompt: "slow down")) {}
            XCTFail("Expected rate limit")
        } catch let error as AppError {
            guard case .aiRateLimited(let name) = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertEqual(name, "Gateway")
        }
    }

    // MARK: - Cancellation

    func testCancellationStopsRequestAndYieldsNoFurtherDeltas() async throws {
        let session = makeSession()
        let slowBody = """
        event: meta
        data: {"route":"cloud","model":"fake","trainsOnPrompts":false}

        event: delta
        data: {"text":"one"}

        event: delta
        data: {"text":"two"}

        event: done
        data: {}

        """
        GatewayURLProtocolStub.handlerBox.set { request in
            try Self.sseResponse(
                for: request,
                status: 200,
                body: slowBody,
                chunkDelayNanoseconds: 80_000_000
            )
        }

        let provider = try makeProvider(session: session)
        let collected = LockedArray<AIStreamEvent>()
        let consumer = Task {
            do {
                for try await event in provider.stream(AIRequest(prompt: "cancel me")) {
                    collected.append(event)
                }
            } catch is CancellationError {
                // Expected when the consuming task is cancelled.
            } catch {
                // Swallow other stream errors; cancel + delta assertions are the gate.
            }
        }

        let deadline = ContinuousClock.now + .seconds(3)
        while collected.snapshot().isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(collected.snapshot().isEmpty, "Should receive at least one event before cancel")

        consumer.cancel()
        await consumer.value

        let events = collected.snapshot()
        XCTAssertTrue(GatewayURLProtocolStub.wasCancelled, "URLProtocol stopLoading should run on cancel")
        XCTAssertFalse(events.contains(.delta("two")), "No further deltas after cancel")
        XCTAssertFalse(events.contains(.done(usage: nil)), "Should not emit done after cancel")
    }

    func testSSEParserDecodesIncrementally() throws {
        var parser = SSEParser()
        let first = try parser.append("event: meta\ndata: {\"route\":\"on-device\",\"model\":\"fake\",\"trainsOnPrompts\":false}\n")
        XCTAssertTrue(first.isEmpty, "Unterminated event must not dispatch")
        let second = try parser.append("\n")
        XCTAssertEqual(second, [
            .meta(route: "on-device", model: "fake", trainsOnPrompts: false)
        ])
        let third = try parser.append("event: delta\ndata: {\"text\":\"Hi\"}\n\n")
        XCTAssertEqual(third, [.delta("Hi")])
    }

    // MARK: - Token-in-URL reject

    func testRejectsEmptyDeviceToken() throws {
        let endpoint = try GatewayEndpoint(raw: "https://gateway.example")
        do {
            _ = try GatewayAIProvider(endpoint: endpoint, deviceToken: "   ")
            XCTFail("Expected apiKeyMissing")
        } catch let error as AppError {
            guard case .apiKeyMissing = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeProvider(
        session: URLSession,
        timeouts: GatewayTimeouts = .defaults
    ) throws -> GatewayAIProvider {
        try GatewayAIProvider(
            endpoint: GatewayEndpoint(raw: "https://gateway.example"),
            deviceToken: "test-device-token",
            session: session,
            timeouts: timeouts
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GatewayURLProtocolStub.self]
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }

    private func fixtureText(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/gateway/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func assertAuthorizedChat(_ request: URLRequest) throws {
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/chat")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-device-token")
        XCTAssertNil(request.url?.query)
        XCTAssertNil(request.url?.fragment)
    }

    private static func bodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody, !body.isEmpty {
            return body
        }
        guard let stream = request.httpBodyStream else {
            throw URLError(.zeroByteResource)
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while true {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static func sseResponse(
        for request: URLRequest,
        status: Int,
        body: String,
        chunkDelayNanoseconds: UInt64 = 0,
        hang: Bool = false
    ) throws -> GatewayURLProtocolStub.StubResponse {
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/event-stream"]
            )
        )
        return GatewayURLProtocolStub.StubResponse(
            response: response,
            body: Data(body.utf8),
            chunkDelayNanoseconds: chunkDelayNanoseconds,
            hang: hang
        )
    }
}

// MARK: - Locked collector

private final class LockedArray<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Element] = []

    func append(_ value: Element) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [Element] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}

// MARK: - URLProtocol stub

/// Synchronous URLProtocol stub (same pattern as ProviderHTTPTests).
/// Supports hang-until-cancel and optional per-chunk delays without spawning Tasks.
private final class GatewayURLProtocolStub: URLProtocol {
    struct StubResponse: Sendable {
        let response: HTTPURLResponse
        let body: Data
        let chunkDelayNanoseconds: UInt64
        let hang: Bool

        init(
            response: HTTPURLResponse,
            body: Data,
            chunkDelayNanoseconds: UInt64 = 0,
            hang: Bool = false
        ) {
            self.response = response
            self.body = body
            self.chunkDelayNanoseconds = chunkDelayNanoseconds
            self.hang = hang
        }
    }

    final class HandlerBox: @unchecked Sendable {
        typealias Handler = @Sendable (URLRequest) throws -> StubResponse
        private let lock = NSLock()
        private let condition = NSCondition()
        private var handler: Handler?
        private var cancelled = false

        func set(_ newHandler: Handler?) {
            condition.lock()
            handler = newHandler
            cancelled = false
            condition.broadcast()
            condition.unlock()
        }

        func get() -> Handler? {
            condition.lock()
            defer { condition.unlock() }
            return handler
        }

        func markCancelled() {
            condition.lock()
            cancelled = true
            condition.broadcast()
            condition.unlock()
        }

        var wasCancelled: Bool {
            condition.lock()
            defer { condition.unlock() }
            return cancelled
        }

        /// Block until `stopLoading` marks cancelled (first-event timeout / cancel tests).
        func waitUntilCancelled() {
            condition.lock()
            while !cancelled {
                condition.wait()
            }
            condition.unlock()
        }
    }

    static let handlerBox = HandlerBox()
    static var wasCancelled: Bool { handlerBox.wasCancelled }

    static func reset() {
        handlerBox.set(nil)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Deliver asynchronously so URLSession.bytes(for:) can attach its consumer
        // before didReceive/didLoad/didFinish run (sync delivery drops the body).
        let client = self.client
        let protocolSelf = self
        let request = self.request
        DispatchQueue.global(qos: .userInitiated).async {
            guard let handler = Self.handlerBox.get() else {
                client?.urlProtocol(protocolSelf, didFailWithError: URLError(.badServerResponse))
                return
            }
            do {
                let stub = try handler(request)
                if stub.hang {
                    Self.handlerBox.waitUntilCancelled()
                    client?.urlProtocol(protocolSelf, didFailWithError: URLError(.cancelled))
                    return
                }
                client?.urlProtocol(
                    protocolSelf,
                    didReceive: stub.response,
                    cacheStoragePolicy: .notAllowed
                )
                if stub.chunkDelayNanoseconds == 0 {
                    client?.urlProtocol(protocolSelf, didLoad: stub.body)
                } else {
                    let bodyText = String(decoding: stub.body, as: UTF8.self)
                    let blocks = bodyText.components(separatedBy: "\n\n")
                    for (index, block) in blocks.enumerated() {
                        if Self.handlerBox.wasCancelled { break }
                        let chunk = index < blocks.count - 1 ? block + "\n\n" : block
                        if chunk.isEmpty { continue }
                        client?.urlProtocol(protocolSelf, didLoad: Data(chunk.utf8))
                        let delay = TimeInterval(stub.chunkDelayNanoseconds) / 1_000_000_000
                        Thread.sleep(forTimeInterval: delay)
                    }
                }
                if Self.handlerBox.wasCancelled {
                    client?.urlProtocol(protocolSelf, didFailWithError: URLError(.cancelled))
                } else {
                    client?.urlProtocolDidFinishLoading(protocolSelf)
                }
            } catch {
                client?.urlProtocol(protocolSelf, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        Self.handlerBox.markCancelled()
    }
}
