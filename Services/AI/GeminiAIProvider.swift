import Foundation
import Core

struct GeminiAIProvider: AIProvider {
    let id = "gemini"
    let displayName = "Gemini (Google)"

    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(apiKey: String, model: String = "gemini-3.7-flash", session: URLSession = .shared) throws {
        guard !apiKey.isEmpty else { throw AppError.apiKeyMissing }
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    static func make(apiKey: String, model: String = "gemini-3.7-flash") -> GeminiAIProvider? {
        try? GeminiAIProvider(apiKey: apiKey, model: model)
    }

    var isAvailable: Bool { !apiKey.isEmpty }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        try Task.checkCancellation()
        let data = try await performRequest(request)
        return try decode(data: data, requestID: request.id)
    }

    private func performRequest(_ request: AIRequest) async throws -> Data {
        guard var components = URLComponents(
            string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        ) else {
            throw AppError.configurationMissing("Gemini base URL")
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else {
            throw AppError.configurationMissing("Gemini endpoint")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 45
        urlRequest.httpBody = try JSONEncoder().encode(makeBody(request))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw AppError.networkUnavailable
        }

        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkUnavailable
        }
        guard (200...299).contains(http.statusCode) else {
            throw AppError.aiRequestFailed("Gemini API request failed (HTTP \(http.statusCode))")
        }
        return data
    }

    private func makeBody(_ request: AIRequest) -> GeminiAPI.GenerateContentRequest {
        GeminiAPI.GenerateContentRequest(
            systemInstruction: request.systemPrompt.map {
                .init(parts: [.init(text: $0)])
            },
            contents: [.init(role: "user", parts: [.init(text: request.prompt)])],
            generationConfig: .init(
                temperature: request.temperature,
                maxOutputTokens: request.maxTokens
            )
        )
    }

    private func decode(data: Data, requestID: UUID) throws -> AIResponse {
        let decoded: GeminiAPI.GenerateContentResponse
        do {
            decoded = try JSONDecoder().decode(
                GeminiAPI.GenerateContentResponse.self,
                from: data
            )
        } catch {
            throw AppError.aiRequestFailed("Failed to decode Gemini response")
        }

        guard let candidate = decoded.candidates.first else {
            throw AppError.aiRequestFailed("Gemini response contained no candidates")
        }
        let content = candidate.content.parts.compactMap(\.text).joined()
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.aiRequestFailed("Gemini response contained no text")
        }

        let usage = decoded.usageMetadata.map {
            AIResponse.Usage(
                promptTokens: $0.promptTokenCount ?? 0,
                completionTokens: $0.candidatesTokenCount ?? 0
            )
        }
        return AIResponse(
            requestID: requestID,
            content: content,
            finishReason: candidate.finishReason == "MAX_TOKENS" ? .length : .stop,
            usage: usage
        )
    }
}

private enum GeminiAPI {
    struct GenerateContentRequest: Encodable {
        let systemInstruction: Content?
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    struct Content: Codable {
        let role: String?
        let parts: [Part]

        init(role: String? = nil, parts: [Part]) {
            self.role = role
            self.parts = parts
        }
    }

    struct Part: Codable {
        let text: String?

        init(text: String) {
            self.text = text
        }
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
    }

    struct GenerateContentResponse: Decodable {
        let candidates: [Candidate]
        let usageMetadata: UsageMetadata?
    }

    struct Candidate: Decodable {
        let content: Content
        let finishReason: String?
    }

    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
    }
}
