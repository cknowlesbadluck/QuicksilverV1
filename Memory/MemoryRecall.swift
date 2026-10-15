import Foundation
import Core

/// On-device recall without a model call: answers "what did I tell you about X"
/// from saved notes using a deterministic template. Returns nil whenever it isn't
/// confident, so the caller falls back to the model.
public enum MemoryRecall {
    public struct Answer: Sendable, Equatable {
        public let text: String
        public let itemIDs: [UUID]
    }

    /// Max notes quoted in one answer.
    public static let maxQuoted = 3

    private static let cues = [
        "what did i tell you about ", "what did i say about ", "what do you remember about ",
        "what do you know about my ", "remind me what i said about ", "what have i told you about "
    ]
    private static let stopwords: Set<String> = [
        "the", "a", "an", "my", "me", "i", "about", "of", "to", "and", "is", "it", "that", "this", "your", "you"
    ]

    /// Topic of a recall question, or nil when the question isn't one.
    public static func topic(in query: String) -> String? {
        let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cue = cues.first(where: { lower.hasPrefix($0) }) else { return nil }
        let topic = lower.dropFirst(cue.count).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        return topic.isEmpty ? nil : topic
    }

    static func tokens(_ text: String) -> Set<String> {
        Set(text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stopwords.contains($0) })
    }

    /// Confident only when every content word of the topic appears in a saved note.
    /// Conversation turns are ignored (they echo questions, not facts the user gave).
    public static func answer(to query: String, from items: [MemoryItem]) -> Answer? {
        guard let topic = topic(in: query) else { return nil }
        let wanted = tokens(topic)
        guard !wanted.isEmpty else { return nil }
        let hits = items
            .filter { $0.category != .conversation && wanted.isSubset(of: tokens($0.value)) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(maxQuoted)
        guard !hits.isEmpty else { return nil }
        let quoted = hits.map { "“\($0.value)”" }
        let text = quoted.count == 1
            ? "You told me: \(quoted[0])"
            : "You told me:\n" + quoted.map { "• \($0)" }.joined(separator: "\n")
        return Answer(text: text, itemIDs: hits.map(\.id))
    }
}
