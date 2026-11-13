import Foundation
import Observation
import Core
import Memory
import Personas

@MainActor
@Observable
final class MemoryViewModel {
    private(set) var items: [MemoryItem] = []
    private(set) var isLoading = false
    private(set) var activePolicyLabel: String = ""
    private(set) var lastExportJSON: String?
    private(set) var statusMessage: String?
    /// M4-T5: banner for the most recent persistence failure, nil when healthy.
    private(set) var failureNotice: String?
    /// M4-T5: disclosure when memories live in the Keychain backup store.
    var backupStoreNotice: String? { container.memoryBackend.disclosure }

    private let container: DependencyContainer
    /// Preserve a Spotlight-injected note across ordinary Archive reloads.
    private var focusedNoteID: UUID?
    @ObservationIgnored private var activeLoadID = UUID()

    init(container: DependencyContainer) {
        self.container = container
    }

    /// Loads the Archive. `focusing` is a note opened from Spotlight: it's always included,
    /// even when the active aspect's scoped view or retention threshold would hide it.
    func load(focusing focusedID: UUID? = nil) async {
        let loadID = UUID()
        activeLoadID = loadID
        isLoading = true
        defer {
            if activeLoadID == loadID { isLoading = false }
        }
        if let focusedID { self.focusedNoteID = focusedID }
        let targetID = self.focusedNoteID
        await container.memoryManager.load()
        guard !Task.isCancelled, activeLoadID == loadID else { return }
        if container.memoryManager.lastFailure != .load {
            await container.memoryLoadDidSucceed()
        }
        guard !Task.isCancelled, activeLoadID == loadID else { return }

        let personaID = container.personaManager.activePersonaID
        let policy = container.personaManager.activeMemoryPolicy
        activePolicyLabel = PersonaTheme.policySummary(for: personaID)

        let query = MemoryQuery(
            personaScope: policy.prefersScopedView ? personaID : nil,
            minimumImportance: policy.retentionThreshold
        )
        items = container.memoryManager.items(matching: query, retentionThreshold: policy.retentionThreshold)
            .map { item in
                var copy = item
                copy.importance = MemoryScorer.decayedImportance(for: item)
                return copy
            }
            .sorted {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.updatedAt > $1.updatedAt
            }
        if let targetID, !items.contains(where: { $0.id == targetID }) {
            if var focused = container.memoryManager.items(matching: MemoryQuery()).first(where: { $0.id == targetID }) {
                focused.importance = MemoryScorer.decayedImportance(for: focused)
                items.insert(focused, at: 0)
            } else {
                focusedNoteID = nil
            }
        }
        refreshFailureNotice()
    }

    func refreshFailureNotice() {
        failureNotice = container.memoryManager.lastFailure?.userNotice
    }

    func addQuickNote(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let personaID = container.personaManager.activePersonaID
        let policy = container.personaManager.activeMemoryPolicy

        await container.memoryManager.set(
            key: "note.\(UUID().uuidString.prefix(8))",
            value: trimmed,
            category: .preference,
            metadata: ["source": "user"],
            importanceBoost: policy.writeImportanceHint,
            personaScope: personaID
        )
        await load()
    }

    func delete(id: UUID) async {
        let didDelete = await container.memoryManager.delete(id: id)
        await load()
        statusMessage = didDelete ? "Memory deleted" : "Unable to delete memory"
    }

    func clearAll() async {
        let didClear = await container.memoryManager.clearAll()
        await load()
        statusMessage = didClear ? "All memories cleared" : "Unable to clear all memories"
    }

    func prepareExport() {
        do {
            lastExportJSON = try container.memoryManager.exportJSON()
            statusMessage = "Export ready"
        } catch {
            lastExportJSON = nil
            statusMessage = "Export failed"
        }
    }
}
