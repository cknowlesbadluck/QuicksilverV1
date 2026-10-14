import XCTest
@testable import Quicksilver
import Core
import Memory
import ServicesAI

/// Hardening (phase 9): Brain-level failure matrix. Every failure surfaces a typed
/// error, leaves the Brain in `.warning` (never stuck in `.thinking`), and records
/// no fabricated turn.
@MainActor
final class BrainFailureMatrixTests: XCTestCase {
    private func brain(failingWith error: Error, store: MemoryStore = InMemoryMemoryStore()) throws -> DependencyContainer {
        let suite = "BrainFailureMatrix.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let container = ViewModelTestSupport.makeContainer(
            provider: FailingProvider(error: error),
            defaults: defaults,
            memoryStore: store
        )
        container.featureFlags.set("aiServiceEnabled", enabled: true)
        return container
    }

    private func assertAskFails(_ error: Error, file: StaticString = #filePath, line: UInt = #line) async throws {
        let container = try brain(failingWith: error)
        do {
            _ = try await container.brain.ask("explain recursion")
            XCTFail("Expected failure for \(error)", file: file, line: line)
        } catch {
            XCTAssertTrue(error is AppError || error is URLError, "Untyped error leaked: \(error)", file: file, line: line)
        }
        XCTAssertEqual(container.brain.visualState, .warning, file: file, line: line)
        XCTAssertNotEqual(container.brain.visualState, .thinking, file: file, line: line)
    }

    func testMidStreamNetworkLossFailsCalmly() async throws {
        try await assertAskFails(URLError(.networkConnectionLost))
    }

    func testQuotaExceededFailsCalmly() async throws {
        try await assertAskFails(AppError.budgetExhausted)
        try await assertAskFails(AppError.rateLimited(retryAfter: 0))
    }

    func testMalformedResponseFailsCalmly() async throws {
        try await assertAskFails(AppError.aiRequestFailed("malformed response"))
    }

    func testMemoryStoreFailureIsSurfacedNotFatal() async throws {
        let container = try brain(failingWith: AppError.timedOut, store: FailingMemoryStore())
        await container.brain.remember("buy filament")
        XCTAssertEqual(container.memoryManager.lastFailure, .save)
        // In-memory items stay authoritative even when persistence fails.
        XCTAssertFalse(container.brain.retrieveSnapshot(limit: 5).isEmpty)
    }
}

private struct FailingProvider: AIProvider {
    let error: Error
    let id = "failing"
    let displayName = "Failing"
    let isAvailable = true
    var trainsOnPrompts: Bool { false }
    func complete(_ request: AIRequest) async throws -> AIResponse { throw error }
}

private struct FailingMemoryStore: MemoryStore {
    struct StoreDown: Error {}
    func loadAll() async throws -> [MemoryItem] { [] }
    func save(_ item: MemoryItem) async throws { throw StoreDown() }
    func delete(id: UUID) async throws { throw StoreDown() }
    func deleteAll(in category: MemoryItem.Category) async throws { throw StoreDown() }
}
