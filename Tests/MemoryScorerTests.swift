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

    // MARK: - Category Base Scores

    func testExactCategoryBaseScores() {
        let categoriesAndBases: [(MemoryItem.Category, Double)] = [
            (.system, 0.85),
            (.preference, 0.75),
            (.project, 0.70),
            (.conversation, 0.45),
            (.temporary, 0.25)
        ]

        for (category, expectedBase) in categoriesAndBases {
            let score = MemoryScorer.score(category: category, value: "")
            XCTAssertEqual(score, expectedBase, accuracy: 0.0001, "Failed for category \(category)")
        }
    }

    // MARK: - Length Factor and Upper Clamping

    func testLengthFactorScaling() {
        let baseCategory = MemoryItem.Category.project // base 0.70

        // Length 0 -> lengthFactor = 0.0 -> score = 0.70
        XCTAssertEqual(MemoryScorer.score(category: baseCategory, value: ""), 0.70, accuracy: 0.0001)

        // Length 30 -> lengthFactor = 30/400 = 0.075 -> score = 0.775
        let text30 = String(repeating: "a", count: 30)
        XCTAssertEqual(MemoryScorer.score(category: baseCategory, value: text30), 0.775, accuracy: 0.0001)

        // Length 60 -> lengthFactor = min(60/400, 0.15) = 0.15 -> score = 0.85
        let text60 = String(repeating: "a", count: 60)
        XCTAssertEqual(MemoryScorer.score(category: baseCategory, value: text60), 0.85, accuracy: 0.0001)

        // Length 200 -> lengthFactor capped at 0.15 -> score = 0.85
        let text200 = String(repeating: "a", count: 200)
        XCTAssertEqual(MemoryScorer.score(category: baseCategory, value: text200), 0.85, accuracy: 0.0001)
    }

    func testScoreClampedToMaximumOne() {
        // System base (0.85) + max length factor (0.15) = 1.00
        let text500 = String(repeating: "a", count: 500)
        let maxSystemScore = MemoryScorer.score(category: .system, value: text500)
        XCTAssertEqual(maxSystemScore, 1.0, accuracy: 0.0001)

        // Even with explicit boost or existing higher score, overall score never exceeds 1.0
        let boosted = MemoryScorer.score(category: .system, value: text500, explicitBoost: 1.5)
        XCTAssertEqual(boosted, 1.0, accuracy: 0.0001)
    }

    // MARK: - Explicit Boost Scenarios

    func testExplicitBoostLowerThanBaseScore() {
        // System category base score is 0.85. If explicitBoost is 0.3, max(0.85, 0.3) = 0.85
        let score = MemoryScorer.score(category: .system, value: "", explicitBoost: 0.3)
        XCTAssertEqual(score, 0.85, accuracy: 0.0001)
    }

    func testExplicitBoostHigherThanBaseScore() {
        // Temporary category base is 0.25. If explicitBoost is 0.8, max(0.25, 0.8) = 0.8
        let score = MemoryScorer.score(category: .temporary, value: "", explicitBoost: 0.8)
        XCTAssertEqual(score, 0.8, accuracy: 0.0001)
    }

    func testExplicitBoostBoundaries() {
        let zeroBoost = MemoryScorer.score(category: .project, value: "", explicitBoost: 0.0)
        XCTAssertEqual(zeroBoost, 0.70, accuracy: 0.0001)

        let fullBoost = MemoryScorer.score(category: .temporary, value: "", explicitBoost: 1.0)
        XCTAssertEqual(fullBoost, 1.0, accuracy: 0.0001)
    }

    // MARK: - Existing Importance Scenarios

    func testExistingImportanceHigherThanBaseScore() {
        // Conversation base is 0.45. Existing is 0.80 -> score should be 0.80
        let score = MemoryScorer.score(category: .conversation, value: "", existing: 0.80)
        XCTAssertEqual(score, 0.80, accuracy: 0.0001)
    }

    func testExistingImportanceLowerThanBaseScore() {
        // System base is 0.85. Existing is 0.50 -> score should remain 0.85
        let score = MemoryScorer.score(category: .system, value: "", existing: 0.50)
        XCTAssertEqual(score, 0.85, accuracy: 0.0001)
    }

    func testExplicitBoostOverridesExisting() {
        // Temporary base 0.25. Explicit boost 0.90, existing 0.40. Explicit boost wins.
        let score = MemoryScorer.score(category: .temporary, value: "", explicitBoost: 0.90, existing: 0.40)
        XCTAssertEqual(score, 0.90, accuracy: 0.0001)

        // System base 0.85. Explicit boost 0.10 (clamped/maxed with base to 0.85), existing 0.95.
        // Since explicitBoost != nil, existing 0.95 is ignored. Result should be base 0.85.
        let score2 = MemoryScorer.score(category: .system, value: "", explicitBoost: 0.10, existing: 0.95)
        XCTAssertEqual(score2, 0.85, accuracy: 0.0001)
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

    func testMultipleHalfLivesDecay() {
        let now = Date()
        // Temporary category half-life is 2 days. 4 days = 2 half-lives -> factor (0.5)^2 = 0.25
        let item = MemoryItem(
            key: "decay2",
            category: .temporary,
            value: "content",
            updatedAt: now.addingTimeInterval(-86_400 * 4),
            importance: 0.80
        )
        let decayed = MemoryScorer.decayedImportance(for: item, now: now)
        XCTAssertEqual(decayed, 0.20, accuracy: 0.001)
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
