import Foundation

/// Lightweight in-process event bus.
///
/// Prefer `events()` AsyncStream for ordered, cancellable consumption on the
/// subscriber's actor. Legacy `subscribe` remains for tests and simple handlers.
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

    private var subscribers: [UUID: @Sendable (Event) -> Void] = [:]
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    public init() {}

    /// Legacy fire-and-forget subscription. Prefer `events()` for structured consumption.
    public func subscribe(_ handler: @escaping @Sendable (Event) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = handler
        return id
    }

    public func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        if let continuation = continuations.removeValue(forKey: id) {
            continuation.finish()
        }
    }

    /// Structured event stream. Consumer iterates on its preferred actor.
    /// Termination (cancel or finish) removes the subscriber.
    public func events() -> AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .bufferingNewest(32))
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    public func publish(_ event: Event) {
        for handler in subscribers.values {
            handler(event)
        }
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
