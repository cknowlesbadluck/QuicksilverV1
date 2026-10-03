import Foundation
import Core

/// Lightweight validation of model responses before they enter app state.
enum ResponseValidator: Sendable {

    enum Outcome: Sendable {
        case accept(AIResponse)
        case reject(reason: String)
    }

    /// - Parameter preserveIncomplete: when true, keep `finishReason == .incomplete` through
    ///   empty rejection and the 32k clip (clip still applies; empty still rejects).
    static func validate(_ response: AIResponse, preserveIncomplete: Bool = false) -> Outcome {
        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .reject(reason: "Empty model response")
        }

        let keepIncomplete = preserveIncomplete && response.finishReason == .incomplete

        // Hard cap to protect UI and memory from pathological outputs
        if trimmed.count > 32_000 {
            let clipped = String(trimmed.prefix(32_000))
            let clippedResponse = AIResponse(
                id: response.id,
                requestID: response.requestID,
                content: clipped,
                finishReason: keepIncomplete ? .incomplete : .length,
                usage: response.usage,
                createdAt: response.createdAt
            )
            return .accept(clippedResponse)
        }

        if keepIncomplete {
            return .accept(
                AIResponse(
                    id: response.id,
                    requestID: response.requestID,
                    content: response.content,
                    finishReason: .incomplete,
                    usage: response.usage,
                    createdAt: response.createdAt
                )
            )
        }

        return .accept(response)
    }
}
