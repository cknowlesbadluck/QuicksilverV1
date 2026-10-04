import Foundation

/// Prior chat turn for multi-turn requests.
/// System content stays on `AIRequest.systemPrompt`; history is prior user/assistant turns only.
public struct Message: Sendable, Codable, Equatable {
    public enum Role: String, Sendable, Codable, Equatable {
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Request sent to any AIProvider.
public struct AIRequest: Sendable, Identifiable {
    public let id: UUID
    public let prompt: String
    public let systemPrompt: String?
    /// Prior turns only (not the current `prompt`). Defaults to empty for single-turn call sites.
    public let history: [Message]
    public let temperature: Double
    public let maxTokens: Int
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        prompt: String,
        systemPrompt: String? = nil,
        history: [Message] = [],
        temperature: Double = 0.7,
        maxTokens: Int = 1024,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.history = history
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.metadata = metadata
    }
}
