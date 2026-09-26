import Foundation

/// Brain-facing contract for App Intents and other automation clients.
///
/// MercuryBrain is the sole production conformer. Intents must call only this
/// surface — never PersonaManager, AIService, MemoryManager, or Nexus directly.
/// M3.5 extends this same protocol (memory query/delete, diagnosis); do not add
/// further Core protocols for intelligence.
@MainActor
public protocol IntelligenceSurface: AnyObject {
    /// Natural-language ask. Routes through the Brain's intent/aspect pipeline.
    func ask(_ query: String) async throws -> String

    /// Persist a short user note into memory.
    func remember(_ content: String) async

    /// Ranked memory snapshot for capability reads and diagnostics.
    func snapshot(limit: Int) -> [MemoryItem]

    /// Explicit aspect entry (Shortcuts / diagnostics).
    func switchAspect(to aspect: Aspect) async throws

    /// Compact diagnostic report (aspect + Nexus health signals).
    func statusReport() throws -> String
}

extension IntelligenceSurface {
    public func snapshot() -> [MemoryItem] {
        snapshot(limit: 5)
    }
}
