import XCTest
@testable import Core
@testable import Memory

/// Memory budget at scale (QS roadmap: memory-budget phase). Deterministic, no timing.
/// After retention, conversation turns never exceed the cap, the newest turns survive,
/// and user notes are untouched regardless of volume.
final class MemoryBudgetTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func turn(_ index: Int) -> MemoryItem {
        // One turn per minute, newest at index 0; all within the 90-day age window.
        let date = now.addingTimeInterval(-Double(index) * 60)
        return MemoryItem(key: "turn.\(index)", category: .conversation, value: "t\(index)",
                          createdAt: date, updatedAt: date)
    }

    private func note(_ index: Int) -> MemoryItem {
        let date = now.addingTimeInterval(-Double(index) * 86_400 * 400)
        return MemoryItem(key: "note.\(index)", category: .temporary, value: "n\(index)",
                          createdAt: date, updatedAt: date, metadata: ["source": "mercury-brain"])
    }

    func testTwentyThousandTurnsPruneToTheCapAndKeepTheNewest() {
        let policy = MemoryRetentionPolicy.default
        let turns = (0..<20_000).map(turn)
        let notes = (0..<500).map(note)
        let items = (turns + notes).shuffled()

        let victims = policy.victims(in: items, now: now)
        let victimIDs = Set(victims.map(\.id))
        let survivors = items.filter { !victimIDs.contains($0.id) }
        let survivingTurns = survivors.filter { $0.category == .conversation }

        XCTAssertEqual(survivingTurns.count, policy.maxConversationItems)
        XCTAssertEqual(Set(survivingTurns.map(\.key)), Set((0..<policy.maxConversationItems).map { "turn.\($0)" }),
                       "the newest turns must be the ones kept")
        XCTAssertEqual(survivors.filter { $0.category == .temporary }.count, notes.count, "notes are never pruned")
        XCTAssertTrue(victims.allSatisfy { $0.category == .conversation })
    }

    func testRetentionIsIdempotentOnceWithinBudget() {
        let policy = MemoryRetentionPolicy.default
        let items = (0..<5_000).map(turn) + (0..<50).map(note)
        let victimIDs = Set(policy.victims(in: items, now: now).map(\.id))
        let survivors = items.filter { !victimIDs.contains($0.id) }
        XCTAssertTrue(policy.victims(in: survivors, now: now).isEmpty, "a second pass must remove nothing")
    }

    func testZeroCapRemovesEveryPrunableTurnButNoNotes() {
        let policy = MemoryRetentionPolicy(maxConversationItems: 0)
        let items = (0..<100).map(turn) + (0..<10).map(note)
        let victims = policy.victims(in: items, now: now)
        XCTAssertEqual(victims.count, 100)
        XCTAssertTrue(victims.allSatisfy { $0.category == .conversation })
    }
}
