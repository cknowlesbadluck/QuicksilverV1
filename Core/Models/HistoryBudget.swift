import Foundation

/// Hard cap for prior turns sent to any provider.
/// The current prompt is not part of history and is never dropped here.
public enum HistoryBudget {
    public static let maxTurns = 12
    public static let maxCharactersPerTurn = 4_000

    public struct Window: Equatable, Sendable {
        public let turns: [Message]
        public let droppedTurns: Int
        public let truncatedTurns: Int
    }

    /// Keep the newest non-blank turns. Truncate oversized content instead of
    /// sending an unbounded payload. Blank turns are dropped, not counted as truncated.
    public static func window(_ history: [Message]) -> Window {
        let nonBlank = history.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let droppedForBlank = history.count - nonBlank.count
        let overflow = max(0, nonBlank.count - maxTurns)
        let kept = Array(nonBlank.suffix(maxTurns))
        var truncated = 0
        let turns = kept.map { message -> Message in
            guard message.content.count > maxCharactersPerTurn else { return message }
            truncated += 1
            let end = message.content.index(message.content.startIndex, offsetBy: maxCharactersPerTurn)
            return Message(role: message.role, content: String(message.content[..<end]))
        }
        return Window(turns: turns, droppedTurns: droppedForBlank + overflow, truncatedTurns: truncated)
    }
}
