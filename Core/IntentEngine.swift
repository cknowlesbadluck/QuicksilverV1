import Foundation

/// Produces a Core.Intent from raw user text.
/// Pure, side-effect free, and deliberately simple so it can later be replaced
/// by a learned or LLM-assisted classifier without changing callers.
///
/// Keyword rules are ordered by specificity. Confidence reflects rule strength.
public struct IntentEngine: Sendable {

    public init() {}

    /// Classify free-form text into an Intent.
    public func classify(_ text: String) -> Intent {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else {
            return Intent(kind: .unknown, rawText: text, confidence: 0)
        }

        // High-specificity first
        if containsAny(lower, Self.diagnoseTerms) {
            return Intent(kind: .diagnose, rawText: text, confidence: 0.88)
        }
        if containsAny(lower, Self.rememberTerms) {
            return Intent(kind: .remember, rawText: text, confidence: 0.90)
        }
        if containsAny(lower, Self.retrieveTerms) {
            return Intent(kind: .retrieve, rawText: text, confidence: 0.85)
        }
        if containsAny(lower, Self.createTerms) {
            return Intent(kind: .create, rawText: text, confidence: 0.87)
        }
        if containsAny(lower, Self.observeTerms) {
            return Intent(kind: .observe, rawText: text, confidence: 0.82)
        }
        if containsAny(lower, Self.expressTerms) {
            return Intent(kind: .express, rawText: text, confidence: 0.80)
        }
        if containsAny(lower, Self.switchTerms) {
            return Intent(kind: .switchAspect, rawText: text, confidence: 0.75)
        }

        // Default conversational inquire
        return Intent(kind: .inquire, rawText: text, confidence: 0.65)
    }

    // MARK: - Term lists (kept private and small)

    private static let diagnoseTerms = [
        "diagnose", "why is", "broken", "failing", "crash", "error",
        "battery", "thermal", "network", "health", "what is wrong"
    ]

    private static let rememberTerms = [
        "remember", "note this", "save this", "store", "capture",
        "don't forget", "write down"
    ]

    private static let retrieveTerms = [
        "what did i", "recall", "remind me", "previous", "last time",
        "from memory", "you said"
    ]

    private static let createTerms = [
        "architect", "implement", "refactor", "build", "create",
        "design", "write code", "add feature", "make a"
    ]

    private static let observeTerms = [
        "observe", "watch", "status", "how is", "current state",
        "what is happening", "signals"
    ]

    private static let expressTerms = [
        "explain", "tell me", "summarize", "describe", "say"
    ]

    private static let switchTerms = [
        "switch to forge", "switch to eternal", "become forge",
        "enter forge", "enter eternal", "force persona"
    ]

    /// Efficiently checks if `text` contains any keyword in `keywords`.
    /// Performance note: Using an explicit for-in loop avoids closure allocation overhead
    /// and enables clean short-circuiting upon finding the first matching substring.
    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        for keyword in keywords where text.contains(keyword) {
            return true
        }
        return false
    }
}
