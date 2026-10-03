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
    private let session: URLSession
    private let timeouts: GatewayTimeouts

    public init(
        endpoint: GatewayEndpoint,
        deviceToken: String,
        session: URLSession = .shared,
        timeouts: GatewayTimeouts = .defaults
    ) throws {
        let trimmed = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.apiKeyMissing }
        if GatewayWireDecoder.rejectTokenInURL(endpoint.url.absoluteString) {
            throw GatewayEndpointError.hasQueryOrFragment
        }
        self.endpoint = endpoint
        self.deviceToken = trimmed
        self.session = session
        self.timeouts = timeouts
    }

    /// Production-style factory: reads the device token from Keychain.
    public static func make(
        endpoint: GatewayEndpoint,
        session: URLSession = .shared,
        timeouts: GatewayTimeouts = .defaults
    ) -> GatewayAIProvider? {
        guard let token = KeychainStore.string(forKey: deviceTokenKeychainAccount),
              !token.isEmpty else {
            return nil
        }
        return try? GatewayAIProvider(
            endpoint: endpoint,
            deviceToken: token,
            session: session,
            timeouts: timeouts
        )
    }

    public var isAvailable: Bool { !deviceToken.isEmpty }
    public var modelIdentifier: String { "gateway" }
    /// The gateway advertises training policy per stream via `meta`; default is conservative.
    public var trainsOnPrompts: Bool { false }

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
        return AIResponse(
            requestID: request.id,
            content: content,
            finishReason: .stop,
            usage: usage
        )
    }

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        let endpoint = self.endpoint
        let deviceToken = self.deviceToken
        let session = self.session
        let timeouts = self.timeouts

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.runStream(
                        request: request,
                        endpoint: endpoint,
                        deviceToken: deviceToken,
                        session: session,
                        timeouts: timeouts,
                        continuation: continuation
                    )
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

    // MARK: - Stream execution

    private static func runStream(
        request: AIRequest,
        endpoint: GatewayEndpoint,
        deviceToken: String,
        session: URLSession,
        timeouts: GatewayTimeouts,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) async throws {
        try Task.checkCancellation()
        if GatewayWireDecoder.rejectTokenInURL(endpoint.url.absoluteString) {
            throw GatewayEndpointError.tokenInURL
        }

        var urlRequest = try endpoint.authorizedRequest(path: "v1/chat", deviceToken: deviceToken)
        urlRequest.timeoutInterval = timeouts.connect
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(makeChatBody(request))

        if GatewayWireDecoder.rejectTokenInURL(urlRequest.url?.absoluteString ?? "") {
            throw GatewayEndpointError.tokenInURL
        }

        let clock = StreamTimeoutClock(timeouts: timeouts)
        try await withThrowingTaskGroup(of: Void.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                try await consumeBytes(
                    session: session,
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

    private static func consumeBytes(
        session: URLSession,
        urlRequest: URLRequest,
        clock: StreamTimeoutClock,
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation
    ) async throws {
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw AppError.networkUnavailable
        }

        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkUnavailable
        }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderHTTPError.error(provider: "Gateway", status: http.statusCode)
        }

        var parser = SSEParser()
        var sawTerminal = false

        for try await line in bytes.lines {
            try Task.checkCancellation()
            try clock.check()
            if let wire = try parser.pushLine(line) {
                try clock.markEvent()
                try handleWire(wire, continuation: continuation, sawTerminal: &sawTerminal)
                if sawTerminal { break }
            }
        }

        parser.finish()
        try Task.checkCancellation()
        if !sawTerminal {
            throw GatewayWireDecodeError.incompleteStream
        }
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
    private var gotFirstEvent = false
    private var lastEventAt: ContinuousClock.Instant

    init(timeouts: GatewayTimeouts) {
        self.timeouts = timeouts
        let now = ContinuousClock.now
        self.startedAt = now
        self.lastEventAt = now
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
        let timeouts = self.timeouts
        lock.unlock()

        let now = ContinuousClock.now
        if now - start > .seconds(timeouts.total) {
            throw AppError.aiRequestFailed("Gateway timed out")
        }
        if !gotFirst, now - start > .seconds(timeouts.firstEvent) {
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
