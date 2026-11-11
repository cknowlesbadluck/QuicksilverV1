import Foundation
import Core

/// Cloud fallback with personal history pruned (privacy floor unchanged).
///
/// Before: one personal turn anywhere in the history blocked the cloud fallback for every later
/// knowledge question ("What is the capital of Peru?" after "my rent went up"). Now, when only
/// the history makes the turn personal, the flagged turns are dropped together with their paired
/// question or reply, and the pruned request is planned again. It goes out only if the full
/// planner says `.cloudEligible`, so nothing that `plan` would keep local can leave the device.
extension CloudContextPolicy {
    /// The request to send to the cloud after an on-device failure, or nil to keep the turn local.
    public static func cloudFallbackRequest(_ request: AIRequest) -> AIRequest? {
        if plan(request).isCloudEligible { return request }
        guard !request.history.isEmpty else { return nil }
        let history = prunedHistory(request.history)
        guard history.count < request.history.count else { return nil }
        let pruned = AIRequest(
            id: request.id,
            prompt: request.prompt,
            systemPrompt: request.systemPrompt,
            history: history,
            context: request.context,
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            metadata: request.metadata,
            onDeviceHistory: request.onDeviceHistory
        )
        return plan(pruned).isCloudEligible ? pruned : nil
    }

    /// History without personal turns. A personal user turn takes the assistant reply after it
    /// (the reply can echo it); a personal assistant turn takes the user turn before it.
    static func prunedHistory(_ history: [Message]) -> [Message] {
        var dropped = Set<Int>()
        for (index, message) in history.enumerated() where isPersonalText(message.content) {
            dropped.insert(index)
            switch message.role {
            case .user where index + 1 < history.count && history[index + 1].role == .assistant:
                dropped.insert(index + 1)
            case .assistant where index > 0 && history[index - 1].role == .user:
                dropped.insert(index - 1)
            default:
                break
            }
        }
        return history.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
    }
}
