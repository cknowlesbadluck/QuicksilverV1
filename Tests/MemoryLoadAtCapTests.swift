import XCTest
@testable import Core
@testable import Memory

/// QS roadmap phase 2 (memory budget): loading a full memory, meaning 1,000 conversation turns
/// (the retention cap) plus 500 notes, stays fast and keeps everything.
///
/// The ceilings are deliberately generous (CI runners, Thread Sanitizer) so this only fails on a
/// real regression such as quadratic load or retention, not on runner noise. Each test also
/// prints its timing so trends show in the CI log. This is not device evidence (CHR-55).
@MainActor
final class MemoryLoadAtCapTests: XCTestCase {
    private static let turnCount = MemoryRetentionPolicy.default.maxConversationItems
    private static let noteCount = 500
    private static let loadCeiling: Duration = .seconds(15)
    private static let queryCeiling: Duration = .seconds(5)

    private func fixture() -> [MemoryItem] {
        let now = Date()
        let turns = (0..<Self.turnCount).map { index -> MemoryItem in
            let date = now.addingTimeInterval(-Double(index) * 60)
            return MemoryItem(key: "turn.\(index)", category: .conversation, value: "turn \(index)",
                              createdAt: date, updatedAt: date)
        }
        let notes = (0..<Self.noteCount).map { index -> MemoryItem in
            let date = now.addingTimeInterval(-Double(index) * 3_600)
            return MemoryItem(key: "note.\(index)", category: .preference, value: "note number \(index)",
                              createdAt: date, updatedAt: date)
        }
        return turns + notes
    }

    private func assertLoadsWithinCeiling(_ store: MemoryStore, label: String) async {
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        let clock = ContinuousClock()
        let loadTime = await clock.measure { await manager.load() }
        print("MEMORY-LOAD \(label): \(loadTime) for \(manager.items.count) items")

        XCTAssertNil(manager.lastFailure)
        XCTAssertEqual(manager.items.count, Self.turnCount + Self.noteCount, "nothing is lost or pruned at the cap")
        XCTAssertLessThan(loadTime, Self.loadCeiling, "\(label) load regressed: \(loadTime)")

        var hits: [MemoryItem] = []
        let queryTime = clock.measure {
            hits = manager.items(matching: MemoryQuery(text: "note number 499"))
        }
        print("MEMORY-QUERY \(label): \(queryTime)")
        XCTAssertTrue(hits.contains { $0.key == "note.499" }, "the oldest note is still findable at the cap")
        XCTAssertLessThan(queryTime, Self.queryCeiling, "\(label) text query regressed: \(queryTime)")
    }

    func testInMemoryStoreLoadsFullMemoryWithinCeiling() async throws {
        let store = InMemoryMemoryStore()
        for item in fixture() { try await store.save(item) }
        await assertLoadsWithinCeiling(store, label: "in-memory")
    }

    func testSwiftDataStoreLoadsFullMemoryWithinCeiling() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        for item in fixture() { try await store.save(item) }
        await assertLoadsWithinCeiling(store, label: "swiftdata")
    }
}
