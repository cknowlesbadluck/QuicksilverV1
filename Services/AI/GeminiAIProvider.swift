import Foundation
import Core

struct GeminiAIProvider: AIProvider {
    let id = "gemini"
    let displayName = "Gemini 2.5 Flash"

    private let apiKey: String
    private let model: String
    private let session: URLSession

    init(
        apiKey: String,
        model: String = "gemini-2.5-flash",
        session: URLSession = .shared
    ) throws {
        guard !apiKey.isEmpty else { throw AppError.apiKeyMissing }
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    var isAvailable: Bool { !apiKey.isEmpty }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        try Task.checkCancellation()

        guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw AppError.configurationMissing("Gemini endpoint")
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 45
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            systemInstruction: request.systemPrompt.map { .init(parts: [.init(text: $0)]) },
            contents: [.init(role: "user", parts: [.init(text: request.prompt)])],
            generationConfig: .init(
                temperature: request.temperature,
                maxOutputTokens: request.maxTokens
            )
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

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
            throw AppError.aiRequestFailed("Gemini returned HTTP \(http.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            let content = decoded.candidates
                .first?.content.parts
                .compactMap(\.text)
                .joined() ?? ""

            guard !content.isEmpty else {
                throw AppError.aiRequestFailed("Gemini response contained no text")
            }

            return AIResponse(
                requestID: request.id,
                content: content,
                finishReason: .stop
            )
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.aiRequestFailed("Failed to decode Gemini response")
        }
    }

    private struct RequestBody: Codable, Sendable {
        let systemInstruction: Content?
        let contents: [Content]
        let generationConfig: GenerationConfig

        enum CodingKeys: String, CodingKey {
            case systemInstruction
            case contents
            case generationConfig
        }
    }

    private struct Content: Codable, Sendable {
        let role: String?
        let parts: [Part]

        init(role: String? = nil, parts: [Part]) {
            self.role = role
            self.parts = parts
        }
    }

    private struct Part: Codable, Sendable {
        let text: String?

        init(text: String) {
            self.text = text
        }
    }

    private struct GenerationConfig: Codable, Sendable {
        let temperature: Double
        let maxOutputTokens: Int
    }

    private struct ResponseBody: Codable, Sendable {
        let candidates: [Candidate]

        struct Candidate: Codable, Sendable {
            let content: Content
        }
    }
}
