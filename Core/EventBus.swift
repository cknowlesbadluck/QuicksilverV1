import Foundation

/// Lightweight in-process event bus.
///
/// Dual surface:
/// - Callback `subscribe` / `unsubscribe` for existing Nexus / Memory / Persona / AI callers.
/// - `events()` AsyncStream for structured concurrency consumers (SanctumViewModel, etc.).
public actor EventBus {
    public enum Event: Sendable {
        case personaDidChange(personaID: String)
        case memoryDidUpdate(itemID: String)
        case featureFlagDidChange(key: String, enabled: Bool)
        case aiRequestStarted(requestID: String)
        case aiRequestCompleted(requestID: String)
        case signalReceived(source: String, value: String, numericValue: Double?)
        case focusDidChange(focusName: String?)
        case timeContextDidChange(period: TimePeriod)
        case batteryPressureChanged(level: Double, isLowPower: Bool)
        case thermalPressureChanged(state: String)
        case networkConditionChanged(isConnected: Bool, isConstrained: Bool)
        case custom(name: String, payload: [String: String])
    }

    public enum TimePeriod: String, Sendable {
        case earlyMorning
        case morning
        case afternoon
        case evening
        case night
    }

    /// A stream subscriber plus its optional, per-stream filter.
    private struct StreamSubscription: Sendable {
        let continuation: AsyncStream<Event>.Continuation
        let isIncluded: @Sendable (Event) -> Bool
    }

    private var subscribers: [UUID: (Event) -> Void] = [:]
    private var continuations: [UUID: StreamSubscription] = [:]

    public init() {}

    public func subscribe(_ handler: @escaping @Sendable (Event) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = handler
        return id
    }

    public func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        if let subscription = continuations.removeValue(forKey: id) {
            subscription.continuation.finish()
        }
    }

    public func publish(_ event: Event) {
        for handler in subscribers.values {
            handler(event)
        }
        for subscription in continuations.values where subscription.isIncluded(event) {
            subscription.continuation.yield(event)
        }
    }

    /// Structured concurrency surface. Each call creates an independent stream.
    /// The stream is registered before this method returns, so events published
    /// after the `await` completes are always delivered (subject to buffering).
    /// Cancellation of the consuming task finishes the underlying continuation.
    ///
    /// - Parameters:
    ///   - bufferingNewest: Per-stream buffer size (newest events are kept).
    ///   - isIncluded: Per-stream filter applied before buffering, so events this
    ///     consumer ignores can never evict ones it needs. Other subscribers are unaffected.
    public func events(
        bufferingNewest limit: Int = 32,
        where isIncluded: @escaping @Sendable (Event) -> Bool = { _ in true }
    ) -> AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .bufferingNewest(max(1, limit)))
        continuations[id] = StreamSubscription(continuation: continuation, isIncluded: isIncluded)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
