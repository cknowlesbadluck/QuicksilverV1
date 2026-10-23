import Foundation
import Core

/// Summarizes one saved note in a single short line, on this device only.
/// Returns nil when there is nothing to summarize or the on-device model can't answer.
/// There is deliberately no cloud fallback: notes never leave the device for a summary.
public protocol NoteSummarizing: Sendable {
    func summary(of note: String) async -> String?
}

/// Foundation Models implementation, through the existing on-device seam
/// (`OnDeviceAIProvider` → `OnDeviceLanguageModel` → `SystemLanguageModel`).
public struct OnDeviceNoteSummarizer: NoteSummarizing {
    /// Short notes are already their own summary.
    public static let minimumCharacters = 120
    /// Keeps the prompt well inside the small on-device context window.
    public static let maximumInputCharacters = 4_000
    public static let maximumSummaryCharacters = 160
    static let instructions = """
        Summarize the user's note in one short sentence. Use only facts in the note. \
        Do not add advice, greetings or commentary.
        """

    private let provider: OnDeviceAIProvider?

    public init(provider: OnDeviceAIProvider?) {
        self.provider = provider
    }

    public func summary(of note: String) async -> String? {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= Self.minimumCharacters, let provider, provider.isAvailable else { return nil }
        let request = AIRequest(
            prompt: String(text.prefix(Self.maximumInputCharacters)),
            systemPrompt: Self.instructions,
            temperature: 0.2,
            maxTokens: 80
        )
        guard let reply = try? await provider.complete(request).content else { return nil }
        return Self.clean(reply)
    }

    /// First non-empty line, trimmed and capped; nil when the model returned nothing usable.
    static func clean(_ reply: String) -> String? {
        let line = reply.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        guard let line else { return nil }
        guard line.count > maximumSummaryCharacters else { return line }
        return String(line.prefix(maximumSummaryCharacters - 1)) + "…"
    }
}

extension AIService {
    /// On-device note summaries. nil-returning when Apple Intelligence is unavailable.
    public var noteSummarizer: any NoteSummarizing {
        OnDeviceNoteSummarizer(provider: onDeviceProvider)
    }
}
