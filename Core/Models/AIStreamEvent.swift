import Foundation

/// One event in a streaming AI response.
///
/// Wire order for a successful stream is `meta` → zero or more `delta` → `done`.
/// A mid-stream failure finishes the `AsyncThrowingStream` by throwing (no terminal `done`).
public enum AIStreamEvent: Sendable, Equatable {
    /// Routing metadata, emitted once before the first delta.
    case meta(route: String, model: String, trainsOnPrompts: Bool)
    /// Incremental text fragment.
    case delta(String)
    /// Successful terminal event with optional token usage and the provider finish reason.
    case done(usage: AIResponse.Usage?, finishReason: AIResponse.FinishReason)
}
