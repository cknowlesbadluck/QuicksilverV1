import Foundation
import Core

// MARK: - Capabilities

extension MercuryBrain {

    /// Structured capability invocations.
    func invoke(_ capability: Capability, payload: String = "") async throws -> String {
        switch capability.kind {
        case .memoryWrite:
            await remember(payload.isEmpty ? "(empty note)" : payload)
            return "Remembered."
        case .memoryRead:
            let items = retrieveSnapshot(limit: 5)
            if items.isEmpty { return "No matching memory." }
            return items.map { item in
                let snippet = String(item.value.prefix(140))
                return "[\(item.category.rawValue)] \(snippet)"
            }.joined(separator: "\n")
        case .memoryCorrect:
            await remember("Correction: \(payload)")
            return "Correction recorded."
        case .diagnose:
            return try await ask(
                payload.isEmpty
                    ? "Diagnose current device health, thermal, and power. Be precise."
                    : payload
            )
        case .express:
            return try await ask(payload.isEmpty ? "Summarize current status." : payload)
        case .plan, .invokeTool:
            throw AppError.unsupportedFeature(capability.name)
        }
    }
}
