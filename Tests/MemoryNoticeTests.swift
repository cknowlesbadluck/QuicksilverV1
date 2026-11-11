import XCTest
@testable import Core
@testable import Memory

/// M4-T5: failure banner text and backup-store disclosure.
@MainActor
final class MemoryNoticeTests: XCTestCase {
    func testEveryFailureHasDistinctCalmNotice() {
        let notices = [MemoryManager.Failure.load, .save, .delete].map(\.userNotice)
        XCTAssertEqual(Set(notices).count, 3)
        for notice in notices {
            XCTAssertFalse(notice.lowercased().contains("error"), "calm wording: \(notice)")
            XCTAssertFalse(notice.lowercased().contains("lost"), "never implies data loss: \(notice)")
        }
        XCTAssertTrue(MemoryManager.Failure.load.userNotice.contains("Nothing was deleted"))
    }

    func testOnlyKeychainFallbackIsDisclosed() {
        XCTAssertNil(MemoryBackend.swiftData.disclosure)
        XCTAssertNil(MemoryBackend.injected.disclosure)
        let text = try? XCTUnwrap(MemoryBackend.keychainFallback.disclosure)
        XCTAssertTrue(text?.contains("backup store") == true)
        XCTAssertTrue(text?.contains("on this device") == true)
    }

    func testManagerFailureMapsToNoticeAndClearsOnRecovery() async {
        let store = FlakyStore()
        let manager = MemoryManager(store: store, eventBus: EventBus(), logger: LoggerService())
        await manager.load()
        XCTAssertEqual(manager.lastFailure?.userNotice, MemoryManager.Failure.load.userNotice)
        await store.recover()
        await manager.load()
        XCTAssertNil(manager.lastFailure?.userNotice)
    }
}

private actor FlakyStore: MemoryStore {
    private var failing = true
    func recover() { failing = false }
    func loadAll() async throws -> [MemoryItem] {
        if failing { throw CocoaError(.fileReadUnknown) }
        return []
    }
    func save(_ item: MemoryItem) async throws {}
    func delete(id: UUID) async throws {}
    func deleteAll(in category: MemoryItem.Category) async throws {}
}
