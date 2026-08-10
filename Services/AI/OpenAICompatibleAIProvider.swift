import Foundation
import Core

/// Lightweight OpenAI-compatible transport used by providers such as Groq and OpenRouter.
struct OpenAICompatibleAIProvider: AIProvider {
    let id: String
    let displayName: String

    private let apiKey: String
    private let endpoint: URL
    private let model: String
    private let session: URLSession

    init(
        id: String,
        displayName: String,
        apiKey: String,
        endpoint: URL,
        model: String,
        session: URLSession = .shared
    ) throws {
        guard !apiKey.isEmpty else { throw AppError.apiKeyMissing }
        self.id = id
        self.displayName = displayName
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
        self.session = session
    }

    var isAvailable: Bool { !apiKey.isEmpty }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        try Task.checkCancellation()

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 45
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [Message] = []
        if let systemPrompt = request.systemPrompt, !systemPrompt.isEmpty {
            messages.append(.init(role: "system", content: systemPrompt))
        }
        messages.append(.init(role: "user", content: request.prompt))

        urlRequest.httpBody = try JSONEncoder().encode(
            RequestBody(
                model: model,
                messages: messages,
                temperature: request.temperature,
                maxTokens: request.maxTokens
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AppError.networkUnavailable
        }

        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkUnavailable
        }

        guard (200...299).contains(http.statusCode) else {
            // Never surface the provider response body. It may contain request metadata or secrets.
            throw AppError.aiRequestFailed("\(displayName) returned HTTP \(http.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            guard let choice = decoded.choices.first else {
                throw AppError.aiRequestFailed("\(displayName) returned no choices")
            }

            return AIResponse(
                requestID: request.id,
                content: choice.message.content,
                finishReason: choice.finishReason == "length" ? .length : .stop,
                usage: decoded.usage.map {
                    .init(
                        promptTokens: $0.promptTokens ?? 0,
                        completionTokens: $0.completionTokens ?? 0
                    )
                }
            )
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.aiRequestFailed("Failed to decode \(displayName) response")
        }
    }

    static func groq(apiKey: String, model: String = "openai/gpt-oss-120b") throws -> Self {
        try Self(
            id: "groq",
            displayName: "Groq",
            apiKey: apiKey,
            endpoint: URL(string: "https://api.groq.com/openai/v1/chat/completions")!,
            model: model
        )
    }

    static func openRouterFree(apiKey: String) throws -> Self {
        try Self(
            id: "openrouter-free",
            displayName: "OpenRouter Free",
            apiKey: apiKey,
            endpoint: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
            model: "openrouter/free"
        )
    }

    private struct Message: Codable, Sendable {
        let role: String
        let content: String
    }

    private struct RequestBody: Codable, Sendable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
    }

    private struct ResponseBody: Codable, Sendable {
        let choices: [Choice]
        let usage: Usage?

        struct Choice: Codable, Sendable {
            let message: Message
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }

        struct Usage: Codable, Sendable {
            let promptTokens: Int?
            let completionTokens: Int?

            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
            }
        }
    }
}
