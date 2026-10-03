import XCTest
@testable import Core
@testable import ServicesAI

final class GatewayAIProviderTests: XCTestCase {

    func testHappyPathStreamsMetaDeltaDone() async throws {
        let sse = try fixtureText("happy.sse")
        let captured = LockedArray<URLRequest>()
        let provider = try makeProvider(transport: lineTransport(status: 200, body: sse, captured: captured))
        var collected: [AIStreamEvent] = []
        for try await event in provider.stream(AIRequest(prompt: "Name the active aspect.", systemPrompt: "Be brief")) {
            collected.append(event)
        }
        let request = try XCTUnwrap(captured.snapshot().first)
        try assertAuthorizedChat(request)
        XCTAssertEqual(collected, [
            .meta(route: "on-device", model: "fake", trainsOnPrompts: false),
            .delta("Forge"),
            .done(usage: AIResponse.Usage(promptTokens: 12, completionTokens: 1), finishReason: .stop)
        ])
    }

    func testCompleteAggregatesStream() async throws {
        let sse = try fixtureText("happy.sse")
        let captured = LockedArray<URLRequest>()
        let provider = try makeProvider(transport: lineTransport(status: 200, body: sse, captured: captured))
        let response = try await provider.complete(
            AIRequest(prompt: "Hello", systemPrompt: "Be brief", maxTokens: 64)
        )
        let request = try XCTUnwrap(captured.snapshot().first)
        let body = try bodyData(from: request)
        let decoded = try GatewayWireDecoder.decodeRequest(body)
        XCTAssertEqual(decoded.taskTier, "standard")
        XCTAssertEqual(decoded.privacy, .device)
        XCTAssertEqual(decoded.context, [])
        XCTAssertEqual(decoded.messages.map(\.role), ["system", "user"])
        XCTAssertEqual(decoded.messages.map(\.content), ["Be brief", "Hello"])
        XCTAssertEqual(response.content, "Forge")
        XCTAssertEqual(response.usage?.promptTokens, 12)
        XCTAssertEqual(response.usage?.completionTokens, 1)
    }

    func testMidStreamErrorYieldsPartialThenThrows() async throws {
        let sse = try fixtureText("mid-stream-error.sse")
        let provider = try makeProvider(transport: lineTransport(status: 200, body: sse))
        var collected: [AIStreamEvent] = []
        do {
            for try await event in provider.stream(AIRequest(prompt: "partial")) {
                collected.append(event)
            }
            XCTFail("Expected upstream failure")
        } catch let error as AppError {
            guard case .providerUnavailable = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }
        XCTAssertEqual(collected, [
            .meta(route: "cloud", model: "fake", trainsOnPrompts: true),
            .delta("partial")
        ])
    }

    func testFirstEventTimeout() async throws {
        let provider = try makeProvider(
            transport: hangingTransport(),
            timeouts: GatewayTimeouts(connect: 5, firstEvent: 0.15, idle: 5, total: 5)
        )
        let started = ContinuousClock.now
        do {
            for try await _ in provider.stream(AIRequest(prompt: "timeout")) {
                XCTFail("Should not receive events")
            }
            XCTFail("Expected first-event timeout")
        } catch let error as AppError {
            guard case .timedOut = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        }
        let elapsed = started.duration(to: .now)
        XCTAssertLessThan(elapsed, Duration.seconds(2))
    }

    func testHTTP401MapsToUnauthorized() async throws {
        let provider = try makeProvider(transport: lineTransport(status: 401, body: "{}"))
        do {
            for try await _ in provider.stream(AIRequest(prompt: "nope")) {}
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            guard case .unauthorized = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertFalse(error.localizedDescription.contains("Gateway"))
        }
    }

    func testUnauthorizedFixtureMapsToUnauthorized() async throws {
        let sse = try fixtureText("unauthorized.sse")
        let provider = try makeProvider(transport: lineTransport(status: 200, body: sse))
        do {
            for try await _ in provider.stream(AIRequest(prompt: "nope")) {}
            XCTFail("Expected unauthorized")
        } catch let error as AppError {
            guard case .unauthorized = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertFalse(error.localizedDescription.contains("Gateway"))
        }
    }

    func testRateLimitedFixtureMapsToRateLimited() async throws {
        let sse = try fixtureText("rate-limited.sse")
        let provider = try makeProvider(transport: lineTransport(status: 200, body: sse))
        do {
            for try await _ in provider.stream(AIRequest(prompt: "slow down")) {}
            XCTFail("Expected rate limit")
        } catch let error as AppError {
            guard case .rateLimited(let retryAfter) = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertEqual(retryAfter, 2)
            XCTAssertFalse(error.localizedDescription.contains("Gateway"))
        }
    }

    func testHTTP429MapsToRateLimited() async throws {
        let provider = try makeProvider(transport: lineTransport(status: 429, body: "{}"))
        do {
            for try await _ in provider.stream(AIRequest(prompt: "slow down")) {}
            XCTFail("Expected rate limit")
        } catch let error as AppError {
            guard case .rateLimited = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertFalse(error.localizedDescription.contains("Gateway"))
        }
    }

    func testHTTP429PreservesRetryAfterHeader() async throws {
        let provider = try makeProvider(
            transport: lineTransport(status: 429, body: "{}", retryAfter: 3)
        )
        do {
            for try await _ in provider.stream(AIRequest(prompt: "slow down")) {}
            XCTFail("Expected rate limit")
        } catch let error as AppError {
            guard case .rateLimited(let retryAfter) = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertEqual(retryAfter, 3)
        }
    }

    func testHTTP503MapsToProviderUnavailable() async throws {
        let provider = try makeProvider(transport: lineTransport(status: 503, body: "{}"))
        do {
            for try await _ in provider.stream(AIRequest(prompt: "down")) {}
            XCTFail("Expected provider unavailable")
        } catch let error as AppError {
            guard case .providerUnavailable = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertFalse(error.localizedDescription.contains("Gateway"))
        }
    }

    func testBudgetExhaustedFixture() async throws {
        let sse = try fixtureText("budget-exhausted.sse")
        let provider = try makeProvider(transport: lineTransport(status: 200, body: sse))
        do {
            for try await _ in provider.stream(AIRequest(prompt: "budget")) {}
            XCTFail("Expected budget exhausted")
        } catch let error as AppError {
            guard case .budgetExhausted = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertFalse(error.localizedDescription.contains("Gateway"))
        }
    }

    func testCancellationStopsRequestAndYieldsNoFurtherDeltas() async throws {
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
        let cancelled = LockedFlag()
        let provider = try makeProvider(transport: pacedTransport(body: slowBody, cancelled: cancelled))
        let collected = LockedArray<AIStreamEvent>()
        let consumer = Task {
            do {
                for try await event in provider.stream(AIRequest(prompt: "cancel me")) {
                    collected.append(event)
                }
            } catch is CancellationError {
            } catch {
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
        XCTAssertTrue(cancelled.value, "Transport should observe cancellation")
        XCTAssertFalse(events.contains(.delta("two")), "No further deltas after cancel")
        XCTAssertFalse(events.contains(.done(usage: nil, finishReason: .stop)), "Should not emit done after cancel")
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

    func testSSEParserHandlesCRLFAndBareCR() throws {
        var parser = SSEParser()
        let crlf = try parser.append(
            "event: meta\r\ndata: {\"route\":\"on-device\",\"model\":\"fake\",\"trainsOnPrompts\":false}\r\n\r\n"
        )
        XCTAssertEqual(crlf, [
            .meta(route: "on-device", model: "fake", trainsOnPrompts: false)
        ])

        parser.finish()
        let bare = try parser.append(
            "event: delta\rdata: {\"text\":\"Hi\"}\r\r"
        )
        XCTAssertEqual(bare, [.delta("Hi")])
    }

    func testSSEParserPreservesCrossChunkCRLF() throws {
        var parser = SSEParser()
        let first = try parser.append(
            "event: delta\rdata: {\"text\":\"A\"}\r"
        )
        XCTAssertTrue(first.isEmpty)
        let second = try parser.append("\n\r\n")
        XCTAssertEqual(second, [.delta("A")])
    }

    func testTrainsOnPromptsDefaultsRestrictive() throws {
        let provider = try makeProvider(transport: lineTransport(status: 200, body: ""))
        XCTAssertTrue(provider.trainsOnPrompts)
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
        transport: GatewayStreamTransport,
        timeouts: GatewayTimeouts = .defaults
    ) throws -> GatewayAIProvider {
        try GatewayAIProvider(
            endpoint: GatewayEndpoint(raw: "https://gateway.example"),
            deviceToken: "test-device-token",
            transport: transport,
            timeouts: timeouts
        )
    }

    private func fixtureText(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/gateway/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func assertAuthorizedChat(_ request: URLRequest) throws {
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/chat")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-device-token")
        XCTAssertNil(request.url?.query)
        XCTAssertNil(request.url?.fragment)
    }

    private func bodyData(from request: URLRequest) throws -> Data {
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

    private func lineTransport(
        status: Int,
        body: String,
        captured: LockedArray<URLRequest>? = nil,
        retryAfter: TimeInterval? = nil
    ) -> GatewayStreamTransport {
        GatewayStreamTransport { request in
            captured?.append(request)
            let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let stream = AsyncThrowingStream<String, Error> { continuation in
                for line in lines {
                    continuation.yield(line)
                }
                continuation.finish()
            }
            return GatewayOpenedStream(statusCode: status, lines: stream, retryAfter: retryAfter)
        }
    }

    private func hangingTransport() -> GatewayStreamTransport {
        GatewayStreamTransport { _ in
            let stream = AsyncThrowingStream<String, Error> { continuation in
                let task = Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    continuation.finish()
                }
                continuation.onTermination = { @Sendable _ in task.cancel() }
            }
            return GatewayOpenedStream(statusCode: 200, lines: stream)
        }
    }

    private func pacedTransport(body: String, cancelled: LockedFlag) -> GatewayStreamTransport {
        GatewayStreamTransport { _ in
            let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let stream = AsyncThrowingStream<String, Error> { continuation in
                let task = Task {
                    for line in lines {
                        if Task.isCancelled {
                            cancelled.set(true)
                            continuation.finish(throwing: CancellationError())
                            return
                        }
                        continuation.yield(line)
                        try? await Task.sleep(nanoseconds: 40_000_000)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { @Sendable reason in
                    if case .cancelled = reason { cancelled.set(true) }
                    task.cancel()
                }
            }
            return GatewayOpenedStream(statusCode: 200, lines: stream)
        }
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false
    var value: Bool {
        lock.lock(); defer { lock.unlock() }
        return stored
    }
    func set(_ newValue: Bool) {
        lock.lock(); stored = newValue; lock.unlock()
    }
}


private final class LockedArray<Element>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Element] = []
    func append(_ value: Element) {
        lock.lock(); values.append(value); lock.unlock()
    }
    func snapshot() -> [Element] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
}
