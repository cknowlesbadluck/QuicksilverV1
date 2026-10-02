import Foundation

/// Contract for any language-model backend.
/// Lives in Core so every module can depend on the abstraction without importing Services.
public protocol AIProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    func complete(_ request: AIRequest) async throws -> AIResponse
    /// Streaming surface. Default wraps `complete` as meta → delta → done.
    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error>
}

extension AIProvider {
    /// Default streaming: one `meta`, one `delta` with the full completion text (when non-empty), then `done`.
    /// Cancelling the consuming task invokes `onTermination` and cancels the underlying `complete` work.
    public func stream(_ request: AIRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try Task.checkCancellation()
                    let response = try await complete(request)
                    try Task.checkCancellation()
                    continuation.yield(
                        .meta(route: id, model: displayName, trainsOnPrompts: false)
                    )
                    if !response.content.isEmpty {
                        continuation.yield(.delta(response.content))
                    }
                    continuation.yield(.done(usage: response.usage))
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
