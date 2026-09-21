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
            let items = retrieveSnapshot(limit: 5)
            if items.isEmpty { return "No matching memory." }
            return items.map { String($0.value.prefix(120)) }.joined(separator: "\n")
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

    /// Lightweight ranked memory snapshot for capability reads.
    func retrieveSnapshot(limit: Int = 5) -> [MemoryItem] {
        let policy = personaManager.activeMemoryPolicy
        let query = MemoryQuery(
            personaScope: nil,
            minimumImportance: policy.retentionThreshold,
            limit: limit
        )
        return memoryManager.items(matching: query)
    }
}
