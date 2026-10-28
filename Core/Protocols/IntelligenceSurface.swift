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

// MARK: - Memory notes for App Intents (M3.5-T11)

extension IntelligenceSurface {
    /// User notes only (keys `note.*`, which includes "remember …"). Conversation turns
    /// and system items are never exposed to Shortcuts, Siri or Spotlight.
    /// Filters the whole ranked memory *before* applying `limit`, so a store full of
    /// conversation turns can't push notes out of the window.
    public func memoryNotes(matching query: String? = nil, limit: Int = 20) -> [MemoryItem] {
        let needle = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return snapshot(limit: .max)
            .filter { $0.key.hasPrefix("note.") && $0.category != .conversation }
            .filter { needle.isEmpty || $0.value.lowercased().contains(needle) }
            .prefix(limit)
            .map { $0 }
    }

    public func memoryNote(id: UUID) -> MemoryItem? {
        memoryNotes(limit: .max).first { $0.id == id }
    }
}
