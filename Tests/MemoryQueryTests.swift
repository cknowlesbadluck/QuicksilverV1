import XCTest
@testable import Core
@testable import Memory

final class MemoryQueryTests: XCTestCase {

    let items: [MemoryItem] = [
        MemoryItem(key: "pref.theme", category: .preference, value: "dark", importance: 0.8, personaScope: nil),
        MemoryItem(key: "note.1", category: .temporary, value: "scratch", importance: 0.2, personaScope: "forge"),
        MemoryItem(key: "proj.alpha", category: .project, value: "ship it", importance: 0.9, personaScope: "quicksilver"),
        MemoryItem(key: "conv.1", category: .conversation, value: "hello", importance: 0.4, personaScope: nil)
    ]

    func testFilterByCategory() {
        let result = MemoryQuery(category: .project).apply(to: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.key, "proj.alpha")
    }

    func testFilterByPersonaScope() {
        let result = MemoryQuery(personaScope: "forge").apply(to: items)
        // shared (nil) + forge-scoped
        XCTAssertEqual(result.count, 3)
    }

    func testMinimumImportance() {
        let result = MemoryQuery(minimumImportance: 0.7).apply(to: items)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.key, "proj.alpha") // highest importance first
    }

    func testKeyPrefix() {
        let result = MemoryQuery(keyPrefix: "pref.").apply(to: items)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.key, "pref.theme")
    }

    func testLimit() {
        let result = MemoryQuery(limit: 2).apply(to: items)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].importance, 0.9, accuracy: 0.001)
    }

    func testTextQueryRanksMatchingConversationAboveUnrelated() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let match = MemoryItem(key: "turn.side-store", category: .conversation, value: "SideStore refresh failed on device", createdAt: now, updatedAt: now, importance: 0.4)
        let other = MemoryItem(key: "turn.weather", category: .conversation, value: "Clear skies tomorrow", createdAt: now, updatedAt: now, importance: 0.9)
        let query = MemoryQuery(text: "SideStore refresh", limit: 1)
        let ranked = query.apply(to: [other, match], now: now)
        XCTAssertEqual(ranked.map(\.key), ["turn.side-store"])
    }

    func testTextQueryDropsZeroOverlap() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = MemoryItem(key: "pref.theme", category: .preference, value: "obsidian", createdAt: now, updatedAt: now, importance: 0.8)
        let ranked = MemoryQuery(text: "sidestore").apply(to: [item], now: now)
        XCTAssertTrue(ranked.isEmpty)
    }

    func testExcludingHistoryContentsDropsMatchingTurns() {
        let kept = MemoryItem(key: "note.kept", category: .temporary, value: "coupe in garage", importance: 0.5)
        let prior = MemoryItem(key: "chat.1", category: .conversation, value: "where is the coupe", importance: 0.4)
        let filtered = MemoryQuery.excludingHistoryContents(
            [kept, prior],
            historyContents: ["where is the coupe", "it is downstairs"]
        )
        XCTAssertEqual(filtered.map(\.key), ["note.kept"])
    }

    func testRelevanceScoreIsCosineTimesDecayedImportance() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = MemoryItem(
            key: "note.car",
            category: .temporary,
            value: "coupe",
            createdAt: now,
            updatedAt: now,
            importance: 0.5
        )
        let score = MemoryQuery.relevanceScore(item: item, cosine: 0.8, tokens: ["coupe"], now: now)
        let expected = 0.8 * MemoryScorer.decayedImportance(for: item, now: now)
        XCTAssertEqual(score, expected, accuracy: 0.0001)
    }

    func testRelevanceScoreFallsBackToOverlapTimesDecay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = MemoryItem(
            key: "note.car",
            category: .temporary,
            value: "vehicle parked",
            createdAt: now,
            updatedAt: now,
            importance: 1.0
        )
        let tokens = MemoryQuery.tokens(from: "vehicle")
        let score = MemoryQuery.relevanceScore(item: item, cosine: nil, tokens: tokens, now: now)
        let overlap = MemoryQuery.overlap(item, tokens: tokens)
        let expected = overlap * MemoryScorer.decayedImportance(for: item, now: now)
        XCTAssertEqual(score, expected, accuracy: 0.0001)
        XCTAssertGreaterThan(score, 0)
    }
}
