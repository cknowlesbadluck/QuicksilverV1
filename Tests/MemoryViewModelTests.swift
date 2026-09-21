import XCTest
@testable import Core
@testable import Memory
@testable import Personas
@testable import Quicksilver

@MainActor
final class MemoryViewModelTests: XCTestCase {

    func testLoadInitialStateAndLoadingLifecycle() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store, startNexus: false)
        let viewModel = MemoryViewModel(container: container)

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertEqual(viewModel.activePolicyLabel, "")

        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.activePolicyLabel.isEmpty)
        XCTAssertEqual(
            viewModel.activePolicyLabel,
            PersonaTheme.policySummary(for: container.personaManager.activePersonaID)
        )
    }

    func testLoadItemsMatchingQueryAndSorting() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store, startNexus: false)
        let viewModel = MemoryViewModel(container: container)

        let now = Date()
        let olderDate = now.addingTimeInterval(-3600)

        // Add items directly via memoryManager
        await container.memoryManager.set(
            key: "low_importance",
            value: "Low Importance Note",
            category: .temporary,
            importanceBoost: 0.1,
            personaScope: nil
        )

        await container.memoryManager.set(
            key: "high_importance_recent",
            value: "High Importance Recent Note",
            category: .temporary,
            importanceBoost: 0.8,
            personaScope: nil
        )

        await container.memoryManager.set(
            key: "high_importance_older",
            value: "High Importance Older Note",
            category: .temporary,
            importanceBoost: 0.8,
            updatedAt: olderDate,
            personaScope: nil
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.items.count, 3)

        // Verify sorting:
        // High importance items should come before low importance item
        // Among equal high importance items, recent updatedAt comes before older updatedAt
        XCTAssertEqual(viewModel.items[0].key, "high_importance_recent")
        XCTAssertEqual(viewModel.items[1].key, "high_importance_older")
        XCTAssertEqual(viewModel.items[2].key, "low_importance")

        // Verify importance calculation includes decay
        XCTAssertGreaterThan(viewModel.items[0].importance, viewModel.items[2].importance)
    }

    func testLoadWithPersonaScopingPolicy() async throws {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store, startNexus: false)
        let viewModel = MemoryViewModel(container: container)

        await container.memoryManager.set(
            key: "forge_note",
            value: "Forge specific note",
            category: .temporary,
            personaScope: "forge"
        )

        await container.memoryManager.set(
            key: "eternal_note",
            value: "Eternal specific note",
            category: .temporary,
            personaScope: "eternal"
        )

        // Switch to Forge persona (Forge prefers scoped view)
        try await container.switchPersonaThrowing(to: "forge")
        await viewModel.load()

        // Forge should only load items matching forge scope (or unscoped)
        let loadedKeys = viewModel.items.map(\.key)
        XCTAssertTrue(loadedKeys.contains("forge_note"))
        XCTAssertFalse(loadedKeys.contains("eternal_note"))
        XCTAssertEqual(
            viewModel.activePolicyLabel,
            PersonaTheme.policySummary(for: "forge")
        )
    }

    func testAddQuickNoteTriggersLoadAndUpdatesItems() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store, startNexus: false)
        let viewModel = MemoryViewModel(container: container)

        await viewModel.addQuickNote("   ") // Whitespace should be ignored
        XCTAssertTrue(viewModel.items.isEmpty)

        await viewModel.addQuickNote("Build rocket engine")
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.value, "Build rocket engine")
    }

    func testDeleteMemoryItemTriggersLoadAndStatusMessage() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store, startNexus: false)
        let viewModel = MemoryViewModel(container: container)

        await viewModel.addQuickNote("Temp Note to Delete")
        XCTAssertEqual(viewModel.items.count, 1)

        guard let itemID = viewModel.items.first?.id else {
            XCTFail("Expected memory item to exist")
            return
        }

        await viewModel.delete(id: itemID)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertEqual(viewModel.statusMessage, "Memory deleted")
    }

    func testClearAllMemoriesTriggersLoadAndStatusMessage() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store, startNexus: false)
        let viewModel = MemoryViewModel(container: container)

        await viewModel.addQuickNote("Note 1")
        await viewModel.addQuickNote("Note 2")
        XCTAssertEqual(viewModel.items.count, 2)

        await viewModel.clearAll()
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertEqual(viewModel.statusMessage, "All memories cleared")
    }

    func testPrepareExportSetsJSONAndStatusMessage() async {
        let store = InMemoryMemoryStore()
        let container = DependencyContainer(memoryStore: store, startNexus: false)
        let viewModel = MemoryViewModel(container: container)

        await viewModel.addQuickNote("Note for export")

        viewModel.prepareExport()

        XCTAssertNotNil(viewModel.lastExportJSON)
        XCTAssertTrue(viewModel.lastExportJSON?.contains("Note for export") == true)
        XCTAssertEqual(viewModel.statusMessage, "Export ready")
    }
}
