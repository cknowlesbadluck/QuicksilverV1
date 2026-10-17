import XCTest
import Core
@testable import ServicesAI

/// Gateway stream watchdog: deadline-driven (no 50 ms polling), never late, and the
/// critical-path error mapping at the provider boundary.
final class GatewayStreamDeadlineTests: XCTestCase {
    private let t0 = ContinuousClock.now

    private func clock(
        connect: TimeInterval = 10, firstEvent: TimeInterval = 20, idle: TimeInterval = 15, total: TimeInterval = 90
    ) -> StreamTimeoutClock {
        StreamTimeoutClock(
            timeouts: GatewayTimeouts(connect: connect, firstEvent: firstEvent, idle: idle, total: total),
            startedAt: t0
        )
    }

    // MARK: Deadlines (deterministic, injected instants)

    func testDeadlineFollowsEachPhase() {
        let watchdog = clock()
        XCTAssertEqual(watchdog.nextDeadline(), t0 + .seconds(10), "before headers: connect")
        watchdog.markResponseStarted(at: t0 + .seconds(1))
        XCTAssertEqual(watchdog.nextDeadline(), t0 + .seconds(21), "after headers: first event")
        watchdog.markEvent(at: t0 + .seconds(2))
        XCTAssertEqual(watchdog.nextDeadline(), t0 + .seconds(17), "streaming: idle, which is earlier")
        watchdog.markEvent(at: t0 + .seconds(80))
        XCTAssertEqual(watchdog.nextDeadline(), t0 + .seconds(90), "total caps everything")
    }

    func testCheckBoundariesPerPhase() {
        let watchdog = clock()
        XCTAssertNoThrow(try watchdog.check(now: t0 + .seconds(10)))
        XCTAssertThrowsError(try watchdog.check(now: t0 + .milliseconds(10_001)))
        watchdog.markResponseStarted(at: t0 + .seconds(1))
        XCTAssertNoThrow(try watchdog.check(now: t0 + .seconds(21)))
        XCTAssertThrowsError(try watchdog.check(now: t0 + .milliseconds(21_001)))
        watchdog.markEvent(at: t0 + .seconds(2))
        XCTAssertNoThrow(try watchdog.check(now: t0 + .seconds(17)))
        XCTAssertThrowsError(try watchdog.check(now: t0 + .milliseconds(17_001))) { error in
            XCTAssertTrue(Self.isTimedOut(error), "got \(String(describing: error))")
        }
    }

    /// The wake must never be later than any deadline a future event could create.
    func testWakeIsNeverLaterThanADeadlineAFutureEventCouldCreate() {
        let watchdog = clock(connect: 30, firstEvent: 20, idle: 5)
        XCTAssertEqual(watchdog.nextWake(now: t0), t0 + .seconds(5), "headers + first event could arrive now")
        watchdog.markResponseStarted(at: t0)
        XCTAssertEqual(watchdog.nextWake(now: t0), t0 + .seconds(5), "a first event now would set idle = 5 s")
        watchdog.markEvent(at: t0 + .seconds(1))
        XCTAssertEqual(watchdog.nextWake(now: t0 + .seconds(1)), t0 + .seconds(6), "streaming: only later events remain")
    }

    // MARK: Watch loop (real time, small budgets)

    func testWatchWakesRarelyInsteadOfPolling() async throws {
        let watchdog = StreamTimeoutClock(timeouts: GatewayTimeouts(connect: 60, firstEvent: 60, idle: 60, total: 0.4))
        let started = ContinuousClock.now
        do {
            try await watchdog.watch()
        } catch {
            XCTAssertTrue(Self.isTimedOut(error), "got \(error)")
        }
        XCTAssertLessThan(started.duration(to: .now), .seconds(2))
        XCTAssertLessThanOrEqual(watchdog.wakeCount, 2, "a 50 ms poll would have woken about 8 times")
    }

    func testWatchNeverFinishesNormallyWhenCancelled() async {
        let watchdog = StreamTimeoutClock(timeouts: .defaults)
        let task = Task { () async throws -> Void in try await watchdog.watch() }
        try? await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do {
            try await task.value
            XCTFail("watch() must not return normally")
        } catch {
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
    }

    // MARK: Provider-level timeouts

    /// Regression guard for the deadline design: idle (0.3 s) is far shorter than first-event
    /// (3 s). The timeout must fire on the idle budget, not wait for the longer one.
    func testIdleTimeoutAfterFirstEventIsNotLate() async throws {
        let provider = try makeProvider(
            transport: transport(lines: ["event: delta", #"data: {"text":"hi"}"#, ""], thenHang: true),
            timeouts: GatewayTimeouts(connect: 5, firstEvent: 3, idle: 0.3, total: 10)
        )
        let started = ContinuousClock.now
        let (events, error) = await drain(provider)
        XCTAssertEqual(events, [.delta("hi")])
        XCTAssertTrue(Self.isTimedOut(error), "got \(String(describing: error))")
        XCTAssertLessThan(started.duration(to: .now), .seconds(2), "fired on idle, not on first-event")
    }

    func testConnectTimeoutWhenTheTransportNeverOpens() async throws {
        let hanging = GatewayStreamTransport { _ in
            try await Task.sleep(for: .seconds(10))
            throw URLError(.timedOut)
        }
        let provider = try makeProvider(transport: hanging, timeouts: GatewayTimeouts(connect: 0.2, firstEvent: 5, idle: 5, total: 10))
        let started = ContinuousClock.now
        let (_, error) = await drain(provider)
        XCTAssertTrue(Self.isTimedOut(error), "got \(String(describing: error))")
        XCTAssertLessThan(started.duration(to: .now), .seconds(2))
    }

    // MARK: Error mapping on the critical path

    func testOfflineOpenMapsToNetworkUnavailable() async throws {
        let provider = try makeProvider(transport: GatewayStreamTransport { _ in throw URLError(.notConnectedToInternet) })
        let (events, error) = await drain(provider)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(Self.isNetworkUnavailable(error), "got \(String(describing: error))")
    }

    func testCancelledOpenMapsToCancellationNotANetworkError() async throws {
        let provider = try makeProvider(transport: GatewayStreamTransport { _ in throw URLError(.cancelled) })
        let (_, error) = await drain(provider)
        XCTAssertTrue(error is CancellationError, "got \(String(describing: error))")
    }

    func testConnectionLostMidStreamKeepsPartialThenMapsToNetworkUnavailable() async throws {
        let lines = ["event: delta", #"data: {"text":"par"}"#, ""]
        let provider = try makeProvider(transport: transport(lines: lines, thenFail: URLError(.networkConnectionLost)))
        let (events, error) = await drain(provider)
        XCTAssertEqual(events, [.delta("par")])
        XCTAssertTrue(Self.isNetworkUnavailable(error), "got \(String(describing: error))")
    }

    func testStreamThatEndsWithoutATerminalEventIsRejected() async throws {
        let lines = ["event: delta", #"data: {"text":"cut"}"#, ""]
        let provider = try makeProvider(transport: transport(lines: lines))
        let (events, error) = await drain(provider)
        XCTAssertEqual(events, [.delta("cut")])
        XCTAssertEqual(error as? GatewayWireDecodeError, .incompleteStream, "a truncated reply must not look complete")
    }

    func testUnexpectedStatusIsAnErrorNotAnEmptyReply() async throws {
        let provider = try makeProvider(transport: transport(lines: [], status: 418))
        let (events, error) = await drain(provider)
        XCTAssertTrue(events.isEmpty)
        XCTAssertNotNil(error as? AppError)
    }

    // MARK: Helpers

    private static func isTimedOut(_ error: Error?) -> Bool {
        if case .timedOut? = error as? AppError { return true }
        return false
    }

    private static func isNetworkUnavailable(_ error: Error?) -> Bool {
        if case .networkUnavailable? = error as? AppError { return true }
        return false
    }

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

    private func drain(_ provider: GatewayAIProvider) async -> ([AIStreamEvent], Error?) {
        var events: [AIStreamEvent] = []
        do {
            for try await event in provider.stream(AIRequest(prompt: "q")) { events.append(event) }
            return (events, nil)
        } catch {
            return (events, error)
        }
    }

    private func transport(
        lines: [String],
        status: Int = 200,
        thenFail failure: (any Error & Sendable)? = nil,
        thenHang: Bool = false
    ) -> GatewayStreamTransport {
        GatewayStreamTransport { _ in
            let stream = AsyncThrowingStream<String, Error> { continuation in
                let task = Task {
                    for line in lines { continuation.yield(line) }
                    if thenHang { try? await Task.sleep(for: .seconds(10)) }
                    continuation.finish(throwing: failure)
                }
                continuation.onTermination = { @Sendable _ in task.cancel() }
            }
            return GatewayOpenedStream(statusCode: status, lines: stream)
        }
    }
}
