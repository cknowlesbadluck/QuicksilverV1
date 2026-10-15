import XCTest
@testable import Core
@testable import Memory

/// M4-T4: retention only ever removes conversation turns; user notes survive any age or volume.
final class MemoryRetentionPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func item(_ category: MemoryItem.Category, ageDays: Double, source: String? = nil) -> MemoryItem {
        let date = now.addingTimeInterval(-ageDays * day)
        return MemoryItem(
            key: "k.\(UUID().uuidString)", category: category, value: "v",
            createdAt: date, updatedAt: date,
            metadata: source.map { ["source": $0] } ?? [:]
        )
    }

    func testDefaultsAreDocumentedValues() {
        XCTAssertEqual(MemoryRetentionPolicy.default.maxConversationAge, 90 * day)
        XCTAssertEqual(MemoryRetentionPolicy.default.maxConversationItems, 1_000)
    }

    func testExpiredConversationTurnsArePruned() {
        let old = item(.conversation, ageDays: 91)
        let fresh = item(.conversation, ageDays: 1)
        XCTAssertEqual(MemoryRetentionPolicy.default.victims(in: [old, fresh], now: now).map(\.id), [old.id])
    }

    func testUserNotesAndOtherCategoriesSurviveAnyAge() {
        let keep = [
            item(.temporary, ageDays: 10_000, source: "mercury-brain"), // `remember` notes
            item(.preference, ageDays: 10_000),
            item(.project, ageDays: 10_000),
            item(.system, ageDays: 10_000),
            item(.conversation, ageDays: 10_000, source: "user")
        ]
        XCTAssertTrue(MemoryRetentionPolicy.default.victims(in: keep, now: now).isEmpty)
    }

    func testCapRemovesOldestTurnsFirst() {
        let policy = MemoryRetentionPolicy(maxConversationItems: 2)
        let oldest = item(.conversation, ageDays: 3)
        let mid = item(.conversation, ageDays: 2)
        let newest = item(.conversation, ageDays: 1)
        let note = item(.temporary, ageDays: 5, source: "mercury-brain")
        XCTAssertEqual(policy.victims(in: [newest, note, oldest, mid], now: now).map(\.id), [oldest.id])
    }

    @MainActor
    func testManyWritesInOneSessionNeverExceedTheCap() async {
        let manager = MemoryManager(store: InMemoryMemoryStore(), eventBus: EventBus(), logger: LoggerService())
        manager.retention = MemoryRetentionPolicy(maxConversationItems: 5)
        await manager.set(key: "note.brain.1", value: "my bike is blue", category: .temporary,
                          metadata: ["source": "mercury-brain"])
        for index in 0..<20 {
            await manager.set(key: "chat.\(index)", value: "turn \(index)", category: .conversation)
        }
        XCTAssertLessThanOrEqual(manager.items.filter { $0.category == .conversation }.count, 5)
        XCTAssertEqual(manager.value(for: "note.brain.1", category: .temporary), "my bike is blue")
        XCTAssertNotNil(manager.value(for: "chat.19", category: .conversation), "Newest turn kept")
    }

    @MainActor
    func testLoadAppliesRetention() async throws {
        let store = InMemoryMemoryStore()
        // load() uses the real clock, so date these relative to Date(), not the fixed `now`.
        let old = Date().addingTimeInterval(-400 * day)
        try await store.save(MemoryItem(key: "chat.old", category: .conversation, value: "v", createdAt: old, updatedAt: old))
        try await store.save(MemoryItem(key: "note.old", category: .temporary, value: "v", createdAt: old, updatedAt: old,
                                        metadata: ["source": "mercury-brain"]))
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.load()
        XCTAssertEqual(manager.items.map(\.category), [.temporary])
    }
}
