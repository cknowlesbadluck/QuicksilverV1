import Foundation
import Core

struct GrokAIProvider: AIProvider {
    let id = "grok"
    let displayName = "Grok (xAI)"

    private let apiKey: String
    private let baseURL: URL
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = "grok-3", baseURL: URL? = nil, session: URLSession = .shared) throws {
        guard !apiKey.isEmpty else { throw AppError.apiKeyMissing }

        let resolved: URL
        if let baseURL { resolved = baseURL }
        else if let defaultURL = URL(string: "https://api.x.ai/v1") { resolved = defaultURL }
        else { throw AppError.configurationMissing("xAI base URL") }

        self.apiKey = apiKey
        self.model = model
        self.baseURL = resolved
        self.session = session
    }

    static func make(apiKey: String, model: String = "grok-3") -> GrokAIProvider? {
        try? GrokAIProvider(apiKey: apiKey, model: model)
    }

    var isAvailable: Bool { !apiKey.isEmpty }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        try Task.checkCancellation()

        guard isAvailable else { throw AppError.apiKeyMissing }

        let endpoint = baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 45

        var messages: [GrokAPI.ChatRequest.Message] = []
        if let system = request.systemPrompt, !system.isEmpty {
            messages.append(.init(role: "system", content: system))
        }
        messages.append(.init(role: "user", content: request.prompt))

        let body = GrokAPI.ChatRequest(
            model: model,
            messages: messages,
            temperature: request.temperature,
            max_tokens: request.maxTokens,
            stream: false
        )

        // Construct coders per-request: JSONEncoder/Decoder are not Sendable.
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        urlRequest.httpBody = try encoder.encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Never surface the raw error if it might contain request details
            throw AppError.networkUnavailable
        }

        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkUnavailable
        }

        guard (200...299).contains(http.statusCode) else {
            throw AppError.aiRequestFailed("Grok API request failed (HTTP \(http.statusCode))")
        }

        let decoded: GrokAPI.ChatResponse
        do {
            decoded = try decoder.decode(GrokAPI.ChatResponse.self, from: data)
        } catch {
            throw AppError.aiRequestFailed("Failed to decode Grok response")
        }

        guard let first = decoded.choices.first else {
            throw AppError.aiRequestFailed("Grok response contained no choices")
        }

        let finishReason: AIResponse.FinishReason
        switch first.finish_reason {
        case "length": finishReason = .length
        default: finishReason = .stop
        }

        let usage: AIResponse.Usage? = decoded.usage.map {
            .init(promptTokens: $0.prompt_tokens ?? 0, completionTokens: $0.completion_tokens ?? 0)
        }

        return AIResponse(
            requestID: request.id,
            content: first.message.content,
            finishReason: finishReason,
            usage: usage
        )
    }
}
