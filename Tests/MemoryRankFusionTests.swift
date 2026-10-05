import XCTest
@testable import Core
@testable import Memory

final class MemoryRankFusionTests: XCTestCase {

    func testSemanticHitSurfacesWithoutSharedTokens() {
        let garage = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            key: "note.car",
            category: .temporary,
            value: "the coupe is in the garage",
            importance: 0.3
        )
        let unrelated = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            key: "note.other",
            category: .temporary,
            value: "buy oat milk",
            importance: 0.9
        )
        let fused = MemoryRankFusion.fuse(
            pool: [unrelated, garage],
            vectorMatches: [EmbeddingIndex.Match(id: garage.id, score: 0.81)],
            text: "where is the vehicle",
            limit: 2
        )
        XCTAssertEqual(fused.first?.id, garage.id)
    }

    func testWeakCosineDoesNotOverrideLexical() {
        let lexical = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            key: "note.vehicle",
            category: .temporary,
            value: "vehicle parked on oak street",
            importance: 0.4
        )
        let weak = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            key: "note.noise",
            category: .temporary,
            value: "unrelated scratch",
            importance: 0.99
        )
        let fused = MemoryRankFusion.fuse(
            pool: [weak, lexical],
            vectorMatches: [EmbeddingIndex.Match(id: weak.id, score: 0.05)],
            text: "vehicle",
            limit: 2
        )
        XCTAssertEqual(fused.map(\.id), [lexical.id])
    }

    func testDeletedVectorIDIsIgnored() {
        let kept = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            key: "note.kept",
            category: .temporary,
            value: "vehicle stays",
            importance: 0.5
        )
        let fused = MemoryRankFusion.fuse(
            pool: [kept],
            vectorMatches: [
                EmbeddingIndex.Match(id: UUID(), score: 0.99),
                EmbeddingIndex.Match(id: kept.id, score: 0.4)
            ],
            text: "vehicle",
            limit: 4
        )
        XCTAssertEqual(fused.map(\.id), [kept.id])
    }

    func testZeroLimitReturnsEmpty() {
        let item = MemoryItem(key: "note.x", category: .temporary, value: "vehicle", importance: 0.5)
        let fused = MemoryRankFusion.fuse(
            pool: [item],
            vectorMatches: [EmbeddingIndex.Match(id: item.id, score: 0.9)],
            text: "vehicle",
            limit: 0
        )
        XCTAssertTrue(fused.isEmpty)
    }

    func testDecayLowersStaleMatchWithSameCosine() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // temporary half-life is 2 days — 20 days old is heavily decayed.
        let fresh = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            key: "note.fresh",
            category: .temporary,
            value: "vehicle parked downstairs",
            createdAt: now,
            updatedAt: now,
            importance: 0.8
        )
        let stale = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            key: "note.stale",
            category: .temporary,
            value: "vehicle parked upstairs",
            createdAt: now.addingTimeInterval(-20 * 86_400),
            updatedAt: now.addingTimeInterval(-20 * 86_400),
            importance: 0.8
        )
        let fused = MemoryRankFusion.fuse(
            pool: [stale, fresh],
            vectorMatches: [
                EmbeddingIndex.Match(id: stale.id, score: 0.7),
                EmbeddingIndex.Match(id: fresh.id, score: 0.7)
            ],
            text: "where is the vehicle",
            limit: 2,
            now: now
        )
        XCTAssertEqual(fused.map(\.id), [fresh.id, stale.id])
    }

    func testCosineTimesDecayBeatsImportantIrrelevant() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let relevant = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            key: "note.relevant",
            category: .temporary,
            value: "coupe lives in the garage",
            createdAt: now,
            updatedAt: now,
            importance: 0.2
        )
        let important = MemoryItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            key: "note.important",
            category: .temporary,
            value: "oat milk is running low",
            createdAt: now,
            updatedAt: now,
            importance: 0.99
        )
        let fused = MemoryRankFusion.fuse(
            pool: [important, relevant],
            vectorMatches: [EmbeddingIndex.Match(id: relevant.id, score: 0.85)],
            text: "where is the vehicle",
            limit: 2,
            now: now
        )
        XCTAssertEqual(fused.first?.id, relevant.id)
    }
}
