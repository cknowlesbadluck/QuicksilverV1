import Foundation
import Core

/// Scripted streaming provider for SPM, AppTests, and `-uitest`.
///
/// Never selected by production routing. Emits a predetermined event sequence with optional
/// inter-event delays and an optional mid-stream failure. Cancelling the consuming task
/// terminates via `onTermination` and cancels the producer Task (recorded on `didCancelStream`).
public struct FakeStreamingProvider: AIProvider {
    public let id: String
    public let displayName: String
    public let isAvailable: Bool
    public let modelIdentifier: String
    public let trainsOnPrompts: Bool

    /// Events to yield, in order. Typically starts with `meta` and ends with `done`.
    public let events: [AIStreamEvent]
    /// Sleep applied before each event (including the first).
    public let delayNanoseconds: UInt64
    /// When non-`nil`, fail after this many successful yields (0 = fail before any event).
    /// A failure scheduled for the index of a `.done` event throws *instead of* yielding `.done`.
    public let failureIndex: Int?
    public let failureError: AppError

    private let cancellationBox: CancellationBox

    /// True once a consuming task cancelled a stream from this provider instance.
    public var didCancelStream: Bool { cancellationBox.value }

    public init(
        id: String = "fake-stream",
        displayName: String = "Fake Streaming Provider",
        isAvailable: Bool = true,
        modelIdentifier: String = "fake-model",
        trainsOnPrompts: Bool = false,
        events: [AIStreamEvent],
        delayNanoseconds: UInt64 = 0,
        failureIndex: Int? = nil,
        failureError: AppError = .aiRequestFailed("scripted mid-stream failure")
    ) {
        self.id = id
        self.displayName = displayName
        self.isAvailable = isAvailable
        self.modelIdentifier = modelIdentifier
        self.trainsOnPrompts = trainsOnPrompts
        self.events = events
        self.delayNanoseconds = delayNanoseconds
        self.failureIndex = failureIndex
        self.failureError = failureError
        self.cancellationBox = CancellationBox()
    }

    /// Convenience: meta + ordered deltas + done.
    public static func deltas(
        _ fragments: [String],
        route: String = "fake",
        model: String = "fake-model",
        trainsOnPrompts: Bool = false,
        usage: AIResponse.Usage? = AIResponse.Usage(promptTokens: 1, completionTokens: 1),
        delayNanoseconds: UInt64 = 0
    ) -> FakeStreamingProvider {
        var scripted: [AIStreamEvent] = [
            .meta(route: route, model: model, trainsOnPrompts: trainsOnPrompts)
        ]
        scripted.append(contentsOf: fragments.map { AIStreamEvent.delta($0) })
        scripted.append(.done(usage: usage))
        return FakeStreamingProvider(
            modelIdentifier: model,
            trainsOnPrompts: trainsOnPrompts,
            events: scripted,
            delayNanoseconds: delayNanoseconds
        )
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        var content = ""
        var usage: AIResponse.Usage?
        var yielded = 0
        for event in events {
            if shouldFail(beforeYielding: event, yielded: yielded) {
                throw failureError
            }
            switch event {
            case .meta:
                break
            case .delta(let fragment):
                content += fragment
            case .done(let doneUsage):
                usage = doneUsage
            }
            yielded += 1
        }
        if let failureIndex, yielded == failureIndex {
            throw failureError
        }
        return AIResponse(
            requestID: request.id,
            content: content,
            finishReason: .stop,
            usage: usage
        )
    }

    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        _ = request
        let scriptedEvents = events
        let interEventDelay = delayNanoseconds
        let failAt = failureIndex
        let failWith = failureError
        let box = cancellationBox

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var yielded = 0
                    for event in scriptedEvents {
                        try Task.checkCancellation()
                        if Self.shouldFail(failureIndex: failAt, beforeYielding: event, yielded: yielded) {
                            throw failWith
                        }
                        if interEventDelay > 0 {
                            try await Task.sleep(nanoseconds: interEventDelay)
                        }
                        try Task.checkCancellation()
                        continuation.yield(event)
                        yielded += 1
                    }
                    if let failAt, yielded == failAt {
                        throw failWith
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable termination in
                task.cancel()
                if case .cancelled = termination {
                    box.mark()
                }
            }
        }
    }

    private func shouldFail(beforeYielding event: AIStreamEvent, yielded: Int) -> Bool {
        Self.shouldFail(failureIndex: failureIndex, beforeYielding: event, yielded: yielded)
    }

    /// Fail when `failureIndex` equals the current yield count, or when the next event would be
    /// `.done` and failure is scheduled for immediately after that yield (never emit `.done` then throw).
    private static func shouldFail(
        failureIndex: Int?,
        beforeYielding event: AIStreamEvent,
        yielded: Int
    ) -> Bool {
        guard let failureIndex else { return false }
        if yielded == failureIndex { return true }
        if case .done = event, failureIndex == yielded + 1 { return true }
        return false
    }
}

/// Shared cancel flag so `FakeStreamingProvider` value copies still report cancellation.
private final class CancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didCancel = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didCancel
    }

    func mark() {
        lock.lock()
        defer { lock.unlock() }
        didCancel = true
    }
}
