import XCTest
@testable import Core
@testable import Memory
@testable import Personas
#if canImport(Quicksilver)
@testable import Quicksilver
#endif

@MainActor
final class MemoryViewModelTests: XCTestCase {

#if canImport(Quicksilver)
    private var container: DependencyContainer!
    private var viewModel: MemoryViewModel!

    override func setUp() async throws {
        try await super.setUp()
        container = DependencyContainer()
        viewModel = MemoryViewModel(container: container)
        await container.memoryManager.clearAll()
    }

    override func tearDown() async throws {
        if container != nil {
            await container.memoryManager.clearAll()
        }
        viewModel = nil
        container = nil
        try await super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.activePolicyLabel.isEmpty)
        XCTAssertNil(viewModel.lastExportJSON)
        XCTAssertNil(viewModel.statusMessage)
    }

    func testLoadAndSortMemories() async {
        await container.memoryManager.set(
            key: "pref.low",
            value: "Low Importance",
            category: .preference,
            importanceBoost: 0.1
        )
        await container.memoryManager.set(
            key: "pref.high",
            value: "High Importance",
            category: .preference,
            importanceBoost: 0.9
        )

        await viewModel.load()

        XCTAssertFalse(viewModel.isLoading)
        let expectedLabel = PersonaTheme.policySummary(for: container.personaManager.activePersonaID)
        XCTAssertEqual(viewModel.activePolicyLabel, expectedLabel)
        XCTAssertGreaterThanOrEqual(viewModel.items.count, 2)

        if viewModel.items.count >= 2 {
            XCTAssertGreaterThanOrEqual(
                viewModel.items[0].importance,
                viewModel.items[1].importance
            )
        }
    }

    func testAddQuickNoteValid() async {
        await viewModel.addQuickNote("   Remember the milk   ")

        XCTAssertEqual(viewModel.items.count, 1)
        guard let firstItem = viewModel.items.first else {
            XCTFail("Expected an item in viewModel.items")
            return
        }

        XCTAssertEqual(firstItem.value, "Remember the milk")
        XCTAssertEqual(firstItem.category, .temporary)
        XCTAssertTrue(firstItem.key.hasPrefix("note."))
    }

    func testAddQuickNoteEmptyOrWhitespace() async {
        await viewModel.addQuickNote("")
        XCTAssertTrue(viewModel.items.isEmpty)

        await viewModel.addQuickNote("   \n\t   ")
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testDeleteMemory() async {
        await viewModel.addQuickNote("Note to delete")
        XCTAssertEqual(viewModel.items.count, 1)

        guard let noteID = viewModel.items.first?.id else {
            XCTFail("Expected note item ID")
            return
        }

        await viewModel.delete(id: noteID)

        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertEqual(viewModel.statusMessage, "Memory deleted")
    }

    func testClearAll() async {
        await viewModel.addQuickNote("Note 1")
        await viewModel.addQuickNote("Note 2")
        XCTAssertEqual(viewModel.items.count, 2)

        await viewModel.clearAll()

        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertEqual(viewModel.statusMessage, "All memories cleared")
    }

    func testPrepareExportSuccess() async {
        await viewModel.addQuickNote("Export test note")

        viewModel.prepareExport()

        XCTAssertNotNil(viewModel.lastExportJSON)
        XCTAssertEqual(viewModel.statusMessage, "Export ready")

        if let json = viewModel.lastExportJSON {
            XCTAssertTrue(json.contains("Export test note"))
        }
    }
#else
    func testPlaceholderForNonQuicksilverTarget() {
        XCTAssertTrue(true, "Quicksilver target is not available in standalone SPM test suite.")
    }
#endif
}
