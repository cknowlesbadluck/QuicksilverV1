import XCTest
@testable import Core
@testable import Memory

final class SwiftDataMemoryStoreTests: XCTestCase {
    func testSaveUpdateDeleteAndMetadataRoundTrip() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let firstUpdatedAt = Date(timeIntervalSince1970: 1_700_000_100)

        var item = MemoryItem(
            id: id,
            key: "project.note",
            category: .project,
            value: "Initial value",
            createdAt: createdAt,
            updatedAt: firstUpdatedAt,
            metadata: ["source": "test", "thread": "alpha"],
            importance: 0.7,
            personaScope: nil
        )

        try await store.save(item)
        var loaded = try await store.loadAll()
        XCTAssertEqual(loaded, [item])

        item.value = "Updated value"
        item.updatedAt = Date(timeIntervalSince1970: 1_700_000_200)
        item.metadata["thread"] = "beta"
        item.importance = 0.9
        item.personaScope = "eternal"

        try await store.save(item)
        loaded = try await store.loadAll()
        XCTAssertEqual(loaded, [item])

        try await store.delete(id: id)
        loaded = try await store.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testDeleteAllOnlyRemovesRequestedCategory() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        let preference = MemoryItem(
            key: "preference.theme",
            category: .preference,
            value: "controlled chaos"
        )
        let conversation = MemoryItem(
            key: "conversation.turn",
            category: .conversation,
            value: "temporary turn"
        )

        try await store.save(preference)
        try await store.save(conversation)
        try await store.deleteAll(in: .conversation)

        let loaded = try await store.loadAll()
        XCTAssertEqual(loaded, [preference])
    }
}
