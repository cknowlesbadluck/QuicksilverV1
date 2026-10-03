import Foundation
import Core

/// Mercury Gateway SSE client (M3-T3).
///
/// Streams `POST /v1/chat` via `URLSession.bytes(for:)`, parsing events with `SSEParser`
/// and `GatewayWireDecoder`. Not wired into production `AIService` routing yet (M3-T6).
public struct GatewayAIProvider: AIProvider {
    public let id = "gateway"
    public let displayName = "Mercury Gateway"

    /// Keychain account for the device bearer token (bound in M3-T6).
    public static let deviceTokenKeychainAccount = "mercury.gateway.deviceToken"

    private let endpoint: GatewayEndpoint
    private let deviceToken: String
    private let transport: GatewayStreamTransport
    private let timeouts: GatewayTimeouts

    public init(
        endpoint: GatewayEndpoint,
        deviceToken: String,
        session: URLSession = GatewayStreamTransport.makeSecureSession(),
        timeouts: GatewayTimeouts = .defaults
    ) throws {
        try self.init(
            endpoint: endpoint,
            deviceToken: deviceToken,
            transport: .urlSession(session),
            timeouts: timeouts
        )
    }

    /// Test and adapter seam. Production uses `urlSession`; unit tests feed lines directly.
    /// `URLSession.bytes(for:)` drops `URLProtocol` bodies on CI, which was failing M3-T3 as incompleteStream.
    public init(
        endpoint: GatewayEndpoint,
        deviceToken: String,
        transport: GatewayStreamTransport,
        timeouts: GatewayTimeouts = .defaults
    ) throws {
        let trimmed = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.apiKeyMissing }
        if GatewayWireDecoder.rejectTokenInURL(endpoint.url.absoluteString) {
            throw GatewayEndpointError.hasQueryOrFragment
        }
        self.endpoint = endpoint
        self.deviceToken = trimmed
        self.transport = transport
        self.timeouts = timeouts
    }

    /// Production-style factory: reads the device token from Keychain.
    public static func make(
        endpoint: GatewayEndpoint,
        session: URLSession = GatewayStreamTransport.makeSecureSession(),
        timeouts: GatewayTimeouts = .defaults
    ) -> GatewayAIProvider? {
        guard let token = KeychainStore.string(forKey: deviceTokenKeychainAccount),
              !token.isEmpty else {
            return nil
        }
        return try? GatewayAIProvider(
            endpoint: endpoint,
            deviceToken: token,
            transport: .urlSession(session),
            timeouts: timeouts
        )
    }

    public var isAvailable: Bool { !deviceToken.isEmpty }
    public var modelIdentifier: String { "gateway" }
    /// Until M3-T4 routing config supplies the tier policy before send, assume training
    /// so callers force minimal context (privacy rule / Gemini free tier).
    public var trainsOnPrompts: Bool { true }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        var content = ""
        var usage: AIResponse.Usage?
        for try await event in stream(request) {
            switch event {
            case .meta:
                break
            case .delta(let fragment):
                content += fragment
            case .done(let doneUsage):
                usage = doneUsage
            }
        }
        try Task.checkCancellation()
        return AIResponse(
            requestID: request.id,
            content: content,
            finishReason: .stop,
            usage: usage
        )
    }

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let deps = GatewayAIStreamEngine.Deps(
            endpoint: endpoint,
            deviceToken: deviceToken,
            transport: transport,
            timeouts: timeouts
        )
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await GatewayAIStreamEngine.run(request, deps: deps, continuation: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Stream engine (kept outside the provider type for SwiftLint type_body_length)

private enum GatewayAIStreamEngine {
    struct Deps: Sendable {
        let endpoint: GatewayEndpoint
        let deviceToken: String
        let transport: GatewayStreamTransport
        let timeouts: GatewayTimeouts
    }

    static func run(
        _ request: AIRequest,
        deps: Deps,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) async throws {
        try Task.checkCancellation()
        if GatewayWireDecoder.rejectTokenInURL(deps.endpoint.url.absoluteString) {
            throw GatewayEndpointError.tokenInURL
        }

        var mutableRequest = try deps.endpoint.authorizedRequest(
            path: "v1/chat",
            deviceToken: deps.deviceToken
        )
        // Do not undercut first-event / idle / total budgets with the connect-only value.
        // StreamTimeoutClock enforces the finer deadlines after the response opens.
        mutableRequest.timeoutInterval = deps.timeouts.total
        mutableRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        mutableRequest.httpBody = try JSONEncoder().encode(makeChatBody(request))

        let urlRequest = mutableRequest
        if GatewayWireDecoder.rejectTokenInURL(urlRequest.url?.absoluteString ?? "") {
            throw GatewayEndpointError.tokenInURL
        }

        let clock = StreamTimeoutClock(timeouts: deps.timeouts)
        let transport = deps.transport
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                try await consumeLines(
                    transport: transport,
                    urlRequest: urlRequest,
                    clock: clock,
                    continuation: continuation
                )
            }
            group.addTask {
                try await clock.watch()
            }
            // First finished child wins: success from consume, or a timeout/error from either.
            try await group.next()
        }
    }

    private static func consumeLines(
        transport: GatewayStreamTransport,
        urlRequest: URLRequest,
        clock: StreamTimeoutClock,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) async throws {
        let opened = try await openTransport(transport, urlRequest: urlRequest)
        try Task.checkCancellation()
        try throwIfHTTPFailed(opened.statusCode)
        clock.markResponseStarted()
        try await readEvents(
            lines: opened.lines,
            clock: clock,
            continuation: continuation
        )
    }

    private static func openTransport(
        _ transport: GatewayStreamTransport,
        urlRequest: URLRequest
    ) async throws -> GatewayOpenedStream {
        do {
            return try await transport.open(urlRequest)
        } catch {
            throw mapTransportFailure(error)
        }
    }

    private static func throwIfHTTPFailed(_ statusCode: Int) throws {
        if statusCode == 401 {
            throw AppError.aiKeyRejected(provider: "Gateway")
        }
        if statusCode == 429 {
            throw AppError.aiRateLimited(provider: "Gateway")
        }
        guard (200...299).contains(statusCode) else {
            throw ProviderHTTPError.error(provider: "Gateway", status: statusCode)
        }
    }

    private static func readEvents(
        lines: AsyncThrowingStream<String, Error>,
        clock: StreamTimeoutClock,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) async throws {
        var parser = SSEParser()
        var sawTerminal = false
        do {
            for try await line in lines {
                try Task.checkCancellation()
                try clock.check()
                if let wire = try parser.pushLine(line) {
                    clock.markEvent()
                    try handleWire(wire, continuation: continuation, sawTerminal: &sawTerminal)
                    if sawTerminal { break }
                }
            }
        } catch let error as AppError {
            throw error
        } catch let error as GatewayWireDecodeError {
            throw error
        } catch {
            throw mapTransportFailure(error)
        }

        parser.finish()
        try Task.checkCancellation()
        if !sawTerminal {
            throw GatewayWireDecodeError.incompleteStream
        }
    }

    private static func mapTransportFailure(_ error: Error) -> Error {
        if error is CancellationError { return CancellationError() }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return CancellationError()
        }
        if Task.isCancelled { return CancellationError() }
        return AppError.networkUnavailable
    }

    private static func handleWire(
        _ wire: GatewayWireEvent,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation,
        sawTerminal: inout Bool
    ) throws {
        switch wire {
        case .meta(let route, let model, let trains):
            continuation.yield(.meta(route: route, model: model, trainsOnPrompts: trains))
        case .delta(let text):
            continuation.yield(.delta(text))
        case .done(let usage):
            continuation.yield(.done(usage: usage))
            sawTerminal = true
        case .error(let code, let retryAfter):
            sawTerminal = true
            throw mapWireError(code, retryAfter: retryAfter)
        }
    }

    private static func makeChatBody(_ request: AIRequest) -> GatewayChatRequest {
        var messages: [GatewayMessage] = []
        if let system = request.systemPrompt, !system.isEmpty {
            messages.append(GatewayMessage(role: "system", content: system))
        }
        messages.append(GatewayMessage(role: "user", content: request.prompt))
        return GatewayChatRequest(
            taskTier: "standard",
            messages: messages,
            context: [],
            privacy: .device,
            maxTokens: request.maxTokens
        )
    }

    private static func mapWireError(_ code: GatewayErrorCode, retryAfter: Int?) -> AppError {
        _ = retryAfter // M3-T5 surfaces retryAfter on a typed case; keep existing AppError surface.
        switch code {
        case .unauthorized:
            return .aiKeyRejected(provider: "Gateway")
        case .rateLimited:
            return .aiRateLimited(provider: "Gateway")
        case .budgetExhausted, .upstreamUnavailable, .badRequest, .timeout:
            return .aiRequestFailed("Gateway request failed")
        }
    }
}

// MARK: - Timeout watchdog

/// Shared first-event / idle / total deadline checks for the stream + watchdog tasks.
private final class StreamTimeoutClock: @unchecked Sendable {
    private let lock = NSLock()
    private let timeouts: GatewayTimeouts
    private let startedAt: ContinuousClock.Instant
    private var responseStartedAt: ContinuousClock.Instant?
    private var gotFirstEvent = false
    private var lastEventAt: ContinuousClock.Instant

    init(timeouts: GatewayTimeouts) {
        self.timeouts = timeouts
        let now = ContinuousClock.now
        self.startedAt = now
        self.lastEventAt = now
    }

    /// Call after response headers / stream open so first-event excludes connect time.
    func markResponseStarted() {
        lock.lock()
        let now = ContinuousClock.now
        responseStartedAt = now
        lastEventAt = now
        lock.unlock()
    }

    func markEvent() {
        lock.lock()
        gotFirstEvent = true
        lastEventAt = ContinuousClock.now
        lock.unlock()
    }

    func check() throws {
        lock.lock()
        let gotFirst = gotFirstEvent
        let lastEvent = lastEventAt
        let start = startedAt
        let responseStart = responseStartedAt
        let timeouts = self.timeouts
        lock.unlock()

        let now = ContinuousClock.now
        if now - start > .seconds(timeouts.total) {
            throw AppError.aiRequestFailed("Gateway timed out")
        }
        // firstEvent starts after headers; before that only `total` applies.
        if !gotFirst, let responseStart,
           now - responseStart > .seconds(timeouts.firstEvent) {
            throw AppError.aiRequestFailed("Gateway timed out waiting for the first event")
        }
        if gotFirst, now - lastEvent > .seconds(timeouts.idle) {
            throw AppError.aiRequestFailed("Gateway stream went idle")
        }
    }

    func watch() async throws {
        do {
            while !Task.isCancelled {
                try check()
                try await Task.sleep(for: .milliseconds(50))
            }
        } catch is CancellationError {
            // Expected when the byte consumer finishes first.
        }
    }
}
