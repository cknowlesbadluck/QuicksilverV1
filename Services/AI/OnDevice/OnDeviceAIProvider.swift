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
    /// M3.5-T4: instructions are capped so the transcript keeps room.
    public static let maxInstructionCharacters = 4_000

    public init(model: any OnDeviceLanguageModel) {
        self.model = model
    }

    public var isAvailable: Bool { model.availability.isAvailable }
    public var availability: OnDeviceModelAvailability { model.availability }

    public func prewarm(instructions: String?) {
        guard isAvailable else { return }
        model.prewarm(instructions: instructions.map(Self.cappedInstructions))
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let availability = model.availability
        guard availability.isAvailable else { throw OnDeviceModelError.unavailable(availability) }
        let instructions = request.systemPrompt.map(Self.cappedInstructions)
        let budget = Self.maxPromptCharacters - (instructions?.count ?? 0)
        do {
            let prompt = try Self.transcript(request, budget: budget, keepHistory: true)
            return try await answer(request, instructions: instructions, prompt: prompt)
        } catch OnDeviceModelError.contextWindowExceeded {
            // One retry with the minimal prompt: question only, no history.
            let prompt = try Self.transcript(request, budget: budget, keepHistory: false)
            return try await answer(request, instructions: instructions, prompt: prompt)
        }
    }

    private func answer(_ request: AIRequest, instructions: String?, prompt: String) async throws -> AIResponse {
        let text = try await model.respond(instructions: instructions, prompt: prompt)
        try Task.checkCancellation()
        return AIResponse(requestID: request.id, content: text)
    }

    /// Keeps the head (identity) and the tail (plain-mode directive, notes) when
    /// over budget, dropping the middle, so mandatory trailing directives survive.
    static func cappedInstructions(_ text: String) -> String {
        guard text.count > maxInstructionCharacters else { return text }
        let marker = "\n…\n"
        let keep = maxInstructionCharacters - marker.count
        let head = keep / 2
        return String(text.prefix(head)) + marker + String(text.suffix(keep - head))
    }

    /// Compact transcript: oldest turns are dropped first when over budget.
    static func transcript(_ request: AIRequest, budget: Int, keepHistory: Bool) throws -> String {
        var turns = keepHistory ? request.history.map { "\($0.role.rawValue): \($0.content)" } : []
        let question = "user: \(request.prompt)"
        func size() -> Int { turns.reduce(question.count) { $0 + $1.count + 1 } }
        while !turns.isEmpty, size() > budget { turns.removeFirst() }
        guard question.count <= budget else { throw OnDeviceModelError.contextWindowExceeded }
        return (turns + [question]).joined(separator: "\n")
    }
}
