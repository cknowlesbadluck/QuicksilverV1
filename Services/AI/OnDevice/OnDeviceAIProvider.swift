import Foundation
import Core

/// M3.5-T2: an `AIProvider` backed by the on-device model. Never trains on
/// prompts and never touches the network. Routing (on-device first, M3.5-T3)
/// is a separate step; this type only adapts the seam to `AIProvider`.
public struct OnDeviceAIProvider: AIProvider {
    public let id = "on-device"
    public let displayName = "Apple Intelligence (on-device)"
    public var modelIdentifier: String { "apple-foundation-model" }
    public var trainsOnPrompts: Bool { false }

    private let model: any OnDeviceLanguageModel
    /// Rough guard for the small on-device context window (≈4k tokens).
    public static let maxPromptCharacters = 12_000

    public init(model: any OnDeviceLanguageModel) {
        self.model = model
    }

    public var isAvailable: Bool { model.availability.isAvailable }
    public var availability: OnDeviceModelAvailability { model.availability }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let availability = model.availability
        guard availability.isAvailable else { throw OnDeviceModelError.unavailable(availability) }

        // Compact transcript: most recent turns first to be dropped when over budget.
        var turns = request.history.map { "\($0.role.rawValue): \($0.content)" }
        let question = "user: \(request.prompt)"
        func size() -> Int { turns.reduce(question.count) { $0 + $1.count + 1 } }
        while !turns.isEmpty, size() > Self.maxPromptCharacters { turns.removeFirst() }
        guard question.count <= Self.maxPromptCharacters else { throw OnDeviceModelError.contextWindowExceeded }
        let prompt = (turns + [question]).joined(separator: "\n")

        let text = try await model.respond(instructions: request.systemPrompt, prompt: prompt)
        try Task.checkCancellation()
        return AIResponse(requestID: request.id, content: text)
    }
}
