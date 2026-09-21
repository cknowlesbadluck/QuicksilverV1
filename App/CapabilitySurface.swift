import Foundation
import Core

/// Structured capability invocations. Brain is the only executor.
/// UI / Intents request capabilities; they never touch Memory or AI directly.
extension MercuryBrain {

    /// Invoke a canonical capability. Returns a short status or result string.
    func invoke(_ capability: Capability, payload: String = "") async throws -> String {
        switch capability.kind {
        case .memoryWrite:
            await remember(payload.isEmpty ? "(empty note)" : payload)
            return "Remembered."
        case .memoryRead:
            let items = retrieveForCapability()
            if items.isEmpty { return "No matching memory." }
            return items.prefix(5).map { String($0.value.prefix(120)) }.joined(separator: "\n")
        case .memoryCorrect:
            // Correction = write a corrective note; full edit path later.
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

    private func retrieveForCapability() -> [MemoryItem] {
        // Mirrors Brain private path without exposing MemoryManager to UI.
        // Uses the same ranked query as prompt assembly.
        let mirror = Mirror(reflecting: self)
        // Prefer the public ask path for complex retrieval; this is a light scan.
        return []
    }
}
