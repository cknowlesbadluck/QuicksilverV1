import XCTest
@testable import Core
@testable import Memory

final class MemoryScorerTests: XCTestCase {

    func testBaseScoreForTemporary() {
        let score = MemoryScorer.score(category: .temporary, value: "short")
        XCTAssertLessThan(score, 0.5)
    }

    func testBaseScoreForProjectHigherThanTemporary() {
        let temp = MemoryScorer.score(category: .temporary, value: "note")
        let project = MemoryScorer.score(category: .project, value: "note")
        XCTAssertGreaterThan(project, temp)
    }

    func testExplicitBoostWins() {
        let score = MemoryScorer.score(category: .temporary, value: "x", explicitBoost: 0.9)
        XCTAssertEqual(score, 0.9, accuracy: 0.01)
    }

    func testExplicitBoostClamped() {
        let over = MemoryScorer.score(category: .preference, value: "x", explicitBoost: 1.5)
        XCTAssertLessThanOrEqual(over, 1.0)
        let under = MemoryScorer.score(category: .preference, value: "x", explicitBoost: -0.2)
        XCTAssertGreaterThanOrEqual(under, 0.0)
    }

    func testDecayReducesImportanceOverTime() {
        let old = MemoryItem(
            key: "old",
            category: .temporary,
            value: "aging",
            createdAt: Date().addingTimeInterval(-10 * 86_400),
            updatedAt: Date().addingTimeInterval(-10 * 86_400),
            importance: 0.8
        )
        let decayed = MemoryScorer.decayedImportance(for: old)
        XCTAssertLessThan(decayed, 0.8)
        XCTAssertGreaterThanOrEqual(decayed, 0.05)
    }

    func testFreshItemBarelyDecays() {
        let fresh = MemoryItem(
            key: "fresh",
            category: .project,
            value: "new",
            importance: 0.7
        )
        let decayed = MemoryScorer.decayedImportance(for: fresh)
        XCTAssertEqual(decayed, 0.7, accuracy: 0.05)
    }

    func testExistingImportanceBlendedOnUpdate() {
        let score = MemoryScorer.score(
            category: .conversation,
            value: "updated note",
            explicitBoost: nil,
            existing: 0.9
        )
        // Should not collapse fully to base; existing influence retained
        XCTAssertGreaterThan(score, 0.4)
        XCTAssertLessThanOrEqual(score, 1.0)
    }

    // MARK: - Edge Cases for decayedImportance

    func testDecayedImportanceWithFutureDate() {
        let now = Date()
        let futureItem = MemoryItem(
            key: "future",
            category: .project,
            value: "future memory",
            updatedAt: now.addingTimeInterval(86_400 * 5), // 5 days in the future relative to `now`
            importance: 0.80
        )
        // `now` is earlier than `updatedAt`, making timeIntervalSince negative.
        // ageDays should clamp to 0, resulting in zero decay factor (pow(0.5, 0) = 1.0).
        let decayed = MemoryScorer.decayedImportance(for: futureItem, now: now)
        XCTAssertEqual(decayed, 0.80, accuracy: 0.001)
    }

    func testDecayedImportanceFloorClamp() {
        let now = Date()
        let ancientItem = MemoryItem(
            key: "ancient",
            category: .temporary,
            value: "ancient memory",
            updatedAt: now.addingTimeInterval(-86_400 * 365), // 1 year old temporary memory
            importance: 0.50
        )
        // Exponential decay should produce a value far below 0.05, but floor clamps it to 0.05.
        let decayed = MemoryScorer.decayedImportance(for: ancientItem, now: now)
        XCTAssertEqual(decayed, 0.05, accuracy: 0.0001)

        let zeroImportanceItem = MemoryItem(
            key: "zero",
            category: .system,
            value: "zero importance",
            updatedAt: now,
            importance: 0.0
        )
        // Importance 0.0 floored to 0.05
        let zeroDecayed = MemoryScorer.decayedImportance(for: zeroImportanceItem, now: now)
        XCTAssertEqual(zeroDecayed, 0.05, accuracy: 0.0001)
    }

    func testDecayedImportanceCeilingClamp() {
        let now = Date()
        let maxItem = MemoryItem(
            key: "max",
            category: .system,
            value: "max importance",
            updatedAt: now,
            importance: 1.0
        )
        let decayed = MemoryScorer.decayedImportance(for: maxItem, now: now)
        XCTAssertEqual(decayed, 1.0, accuracy: 0.0001)
    }

    func testDecayedImportanceExactHalfLife() {
        let now = Date()
        // Temporary half-life is 2 days
        let tempItem = MemoryItem(
            key: "halfLifeTemp",
            category: .temporary,
            value: "temp memory",
            updatedAt: now.addingTimeInterval(-86_400 * 2), // exactly 2 days old
            importance: 0.80
        )
        let decayedTemp = MemoryScorer.decayedImportance(for: tempItem, now: now)
        XCTAssertEqual(decayedTemp, 0.40, accuracy: 0.001)
    }

    func testDecayedImportanceCategoryHalfLives() {
        let now = Date()
        let expectedHalfLives: [MemoryItem.Category: Double] = [
            .temporary: 2,
            .conversation: 7,
            .project: 30,
            .preference: 90,
            .system: 180
        ]

        for (category, halfLifeDays) in expectedHalfLives {
            let item = MemoryItem(
                key: "key_\(category.rawValue)",
                category: category,
                value: "val",
                updatedAt: now.addingTimeInterval(-86_400 * halfLifeDays),
                importance: 0.80
            )
            let decayed = MemoryScorer.decayedImportance(for: item, now: now)
            XCTAssertEqual(
                decayed,
                0.40,
                accuracy: 0.001,
                "Category \(category.rawValue) failed exact half-life decay expectation."
            )
        }
    }
}
