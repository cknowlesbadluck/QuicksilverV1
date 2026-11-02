import XCTest
@testable import Core
@testable import Memory

/// Damaged rows load with an importance in 0...1, so the importance sorts stay well-ordered.
@available(iOS 17.0, macOS 14.0, *)
final class MemoryImportanceSanitizeTests: XCTestCase {
    private func loaded(_ raw: Double) -> Double {
        let entry = MemoryEntry(from: MemoryItem(key: "x", category: .project, value: "v"))
        entry.importance = raw
        return entry.toMemoryItem().importance
    }

    func testNonFiniteImportanceLoadsAsZero() {
        XCTAssertEqual(loaded(.nan), 0)
        XCTAssertEqual(loaded(.infinity), 0)
        XCTAssertEqual(loaded(-.infinity), 0)
    }

    func testOutOfRangeImportanceIsClamped() {
        XCTAssertEqual(loaded(7), 1)
        XCTAssertEqual(loaded(-3), 0)
        XCTAssertEqual(loaded(0.42), 0.42)
    }

    func testDamagedRowsStillSortDeterministically() async throws {
        let store = try SwiftDataMemoryStore(inMemory: true)
        for (index, raw) in [Double.nan, 0.9, .infinity, 0.1].enumerated() {
            var item = MemoryItem(key: "k\(index)", category: .project, value: "v\(index)")
            item.importance = raw
            try await store.save(item)
        }
        let items = try await store.loadAll()
        XCTAssertEqual(items.count, 4, "damaged rows are kept, not dropped")
        XCTAssertTrue(items.allSatisfy { (0...1).contains($0.importance) })
        let sorted = items.sorted { $0.importance > $1.importance }.map(\.key)
        XCTAssertEqual(Array(sorted.prefix(1)), ["k1"])
    }
}
