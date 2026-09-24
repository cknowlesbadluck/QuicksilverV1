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

    private var subscribers: [UUID: (Event) -> Void] = [:]
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    public init() {}

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

    public func publish(_ event: Event) {
        for handler in subscribers.values {
            handler(event)
        }
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Structured concurrency surface. Each call creates an independent stream.
    /// Cancellation of the consuming task finishes the underlying continuation.
    public func events() -> AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .bufferingNewest(32))
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
