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

    /// Events to yield, in order. Typically starts with `meta` and ends with `done`.
    public let events: [AIStreamEvent]
    /// Sleep applied before each event (including the first).
    public let delayNanoseconds: UInt64
    /// When non-`nil`, after yielding this many events the stream throws `failureError`
    /// instead of continuing. Index is the count of already-yielded events (0 = fail before any).
    public let failureIndex: Int?
    public let failureError: AppError

    private let cancellationBox: CancellationBox

    /// True once a consuming task cancelled a stream from this provider instance.
    public var didCancelStream: Bool { cancellationBox.value }

    public init(
        id: String = "fake-stream",
        displayName: String = "Fake Streaming Provider",
        isAvailable: Bool = true,
        events: [AIStreamEvent],
        delayNanoseconds: UInt64 = 0,
        failureIndex: Int? = nil,
        failureError: AppError = .aiRequestFailed("scripted mid-stream failure")
    ) {
        self.id = id
        self.displayName = displayName
        self.isAvailable = isAvailable
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
        return FakeStreamingProvider(events: scripted, delayNanoseconds: delayNanoseconds)
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        var content = ""
        var usage: AIResponse.Usage?
        var yielded = 0
        for event in events {
            if let failureIndex, yielded == failureIndex {
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
                        if let failAt, yielded == failAt {
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
