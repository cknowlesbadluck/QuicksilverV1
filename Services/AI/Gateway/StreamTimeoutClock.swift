import Foundation
import Synchronization
import Core

// MARK: - Timeout watchdog

/// Shared connect / first-event / idle / total deadline checks for the gateway stream.
/// State lives in a `Mutex`, so the type is checked `Sendable` (issue #252).
///
/// Deadline-driven, not polled: `watch()` sleeps until the next instant a deadline could
/// expire (see `nextWake`), re-checks, and re-arms. While a reply streams it wakes about
/// once per idle window instead of 20 times a second (the previous 50 ms loop).
final class StreamTimeoutClock: Sendable {
    private struct State {
        var responseStartedAt: ContinuousClock.Instant?
        var gotFirstEvent = false
        var lastEventAt: ContinuousClock.Instant
        var wakes = 0
    }

    /// Sleep just past a deadline, because `check()` uses strict `>` comparisons.
    static let slack: Duration = .milliseconds(5)

    private let timeouts: GatewayTimeouts
    private let startedAt: ContinuousClock.Instant
    private let state: Mutex<State>

    init(timeouts: GatewayTimeouts, startedAt: ContinuousClock.Instant = .now) {
        self.timeouts = timeouts
        self.startedAt = startedAt
        self.state = Mutex(State(lastEventAt: startedAt))
    }

    /// Call after response headers / stream open so first-event excludes connect time.
    func markResponseStarted(at now: ContinuousClock.Instant = .now) {
        state.withLock { state in
            state.responseStartedAt = now
            state.lastEventAt = now
        }
    }

    func markEvent(at now: ContinuousClock.Instant = .now) {
        state.withLock { state in
            state.gotFirstEvent = true
            state.lastEventAt = now
        }
    }

    /// Times the watchdog woke to check (diagnostics and tests).
    var wakeCount: Int { state.withLock { $0.wakes } }

    /// The earliest instant at which `check()` could throw, given what has happened so far.
    func nextDeadline() -> ContinuousClock.Instant {
        Self.deadline(for: state.withLock { $0 }, startedAt: startedAt, timeouts: timeouts)
    }

    /// When the watchdog should next wake: no later than the current deadline, and no later
    /// than the soonest deadline a future event could create. The response opening or the
    /// first event can pull the deadline *earlier* (for example idle 15 s after a first event
    /// that arrives under a 20 s first-event budget), so a timeout never fires late.
    func nextWake(now: ContinuousClock.Instant = .now) -> ContinuousClock.Instant {
        let snapshot = state.withLock { $0 }
        let deadline = Self.deadline(for: snapshot, startedAt: startedAt, timeouts: timeouts)
        guard !snapshot.gotFirstEvent else { return deadline }
        let soonestNew = snapshot.responseStartedAt == nil
            ? min(timeouts.firstEvent, timeouts.idle)
            : timeouts.idle
        return min(deadline, now + .seconds(soonestNew))
    }

    private static func deadline(
        for snapshot: State,
        startedAt: ContinuousClock.Instant,
        timeouts: GatewayTimeouts
    ) -> ContinuousClock.Instant {
        let total = startedAt + .seconds(timeouts.total)
        guard let responseStart = snapshot.responseStartedAt else {
            return min(total, startedAt + .seconds(timeouts.connect))
        }
        if snapshot.gotFirstEvent {
            return min(total, snapshot.lastEventAt + .seconds(timeouts.idle))
        }
        return min(total, responseStart + .seconds(timeouts.firstEvent))
    }

    func check(now: ContinuousClock.Instant = .now) throws {
        let snapshot = state.withLock { $0 }
        if now - startedAt > .seconds(timeouts.total) {
            throw AppError.timedOut
        }
        // Before headers: enforce connect. After headers: firstEvent / idle.
        guard let responseStart = snapshot.responseStartedAt else {
            if now - startedAt > .seconds(timeouts.connect) { throw AppError.timedOut }
            return
        }
        if !snapshot.gotFirstEvent, now - responseStart > .seconds(timeouts.firstEvent) {
            throw AppError.timedOut
        }
        if snapshot.gotFirstEvent, now - snapshot.lastEventAt > .seconds(timeouts.idle) {
            throw AppError.timedOut
        }
    }

    /// Never returns normally: throws `AppError.timedOut` at a missed deadline, or
    /// `CancellationError` when the stream finishes first and cancels it.
    func watch() async throws -> Never {
        while true {
            try check()
            try await Task.sleep(until: nextWake() + Self.slack, clock: .continuous)
            state.withLock { $0.wakes += 1 }
        }
    }
}
