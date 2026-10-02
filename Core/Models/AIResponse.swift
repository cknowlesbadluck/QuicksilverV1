import Foundation

/// Response returned by any AIProvider.
public struct AIResponse: Sendable, Identifiable {
    public let id: UUID
    public let requestID: UUID
    public let content: String
    public let finishReason: FinishReason
    public let usage: Usage?
    public let createdAt: Date

    public enum FinishReason: String, Sendable {
        case stop, length, error, cancelled
    }

    public struct Usage: Sendable, Equatable {
        public let promptTokens: Int
        public let completionTokens: Int
        public var totalTokens: Int { promptTokens + completionTokens }

        public init(promptTokens: Int, completionTokens: Int) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
        }
    }

    public init(
        id: UUID = UUID(),
        requestID: UUID,
        content: String,
        finishReason: FinishReason = .stop,
        usage: Usage? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.requestID = requestID
        self.content = content
        self.finishReason = finishReason
        self.usage = usage
        self.createdAt = createdAt
    }
}
