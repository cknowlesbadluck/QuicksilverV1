import Foundation
import Core

/// Structured capability invocations.
/// Implemented as Brain methods so private Memory/Persona access stays file-safe.
extension MercuryBrain {

    /// Invoke a canonical capability. Returns a short status or result string.
    func invoke(_ capability: Capability, payload: String = "") async throws -> String {
        switch capability.kind {
        case .memoryWrite:
            await remember(payload.isEmpty ? "(empty note)" : payload)
            return "Remembered."
        case .memoryRead:
            // Use remember-path side channel: ask is heavier; for read we surface living status + insight.
            if let insight = primaryInsight {
                return insight
            }
            return livingStatus
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
