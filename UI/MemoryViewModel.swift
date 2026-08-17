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

    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
    }

    func load() async {
        isLoading = true
        await container.memoryManager.load()

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
        isLoading = false
    }

    func addQuickNote(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let personaID = container.personaManager.activePersonaID
        let policy = container.personaManager.activeMemoryPolicy

        await container.memoryManager.set(
            key: "note.\(UUID().uuidString.prefix(8))",
            value: trimmed,
            category: .temporary,
            importanceBoost: policy.writeImportanceHint,
            personaScope: personaID
        )
        await load()
    }

    func delete(id: UUID) async {
        await container.memoryManager.delete(id: id)
        await load()
        statusMessage = "Memory deleted"
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
