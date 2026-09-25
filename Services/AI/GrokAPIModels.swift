import Foundation

enum GrokAPI {
    struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let maxTokens: Int
        let stream: Bool

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: GrokChatRequestCodingKeys.self)
            try container.encode(model, forKey: .model)
            try container.encode(messages, forKey: .messages)
            try container.encode(temperature, forKey: .temperature)
            try container.encode(maxTokens, forKey: .maxTokens)
            try container.encode(stream, forKey: .stream)
        }
    }

    struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    struct ChatResponse: Decodable {
        let id: String?
        let choices: [ChatChoice]
        let usage: ChatUsage?
    }

    struct ChatChoice: Decodable {
        let message: ChatResponseMessage
        let finishReason: String?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: GrokChatChoiceCodingKeys.self)
            message = try container.decode(ChatResponseMessage.self, forKey: .message)
            finishReason = try container.decodeIfPresent(String.self, forKey: .finishReason)
        }
    }

    struct ChatResponseMessage: Decodable {
        let role: String?
        let content: String
    }

    struct ChatUsage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: GrokChatUsageCodingKeys.self)
            promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
            completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
            totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
        }
    }
}

private enum GrokChatRequestCodingKeys: String, CodingKey {
    case model, messages, temperature, stream
    case maxTokens = "max_tokens"
}

private enum GrokChatChoiceCodingKeys: String, CodingKey {
    case message
    case finishReason = "finish_reason"
}

private enum GrokChatUsageCodingKeys: String, CodingKey {
    case promptTokens = "prompt_tokens"
    case completionTokens = "completion_tokens"
    case totalTokens = "total_tokens"
}
