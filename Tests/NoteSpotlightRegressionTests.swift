import Synchronization
import XCTest
@testable import Core
@testable import QuicksilverIntents

@MainActor
final class NoteSpotlightRegressionTests: XCTestCase {
    func testMemoryNotesExcludeSystemItems() {
        let surface = RegressionNotesSurface(items: [
            MemoryItem(key: "note.saved", category: .preference, value: "visible note"),
            MemoryItem(key: "note.system", category: .system, value: "private system instruction"),
            MemoryItem(key: "note.chat", category: .conversation, value: "private conversation")
        ])

        XCTAssertEqual(surface.memoryNotes().map(\.value), ["visible note"])
    }

    func testSavedNotesIgnoreActiveAspectSnapshotRetentionFiltering() {
        let note = MemoryItem(key: "note.legacy", category: .preference, value: "legacy saved note")
        let surface = RegressionNotesSurface(items: [note])
        surface.snapshotOverride = []
        XCTAssertEqual(surface.memoryNotes().map(\\.value), ["legacy saved note"])
    }

    func testConversationOnlyMemoryUpdateDoesNotRebuildSpotlightIndex() async throws {
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "NoteSpotlightRegression.\(UUID().uuidString)") ?? .standard)
        let index = RegressionNoteIndex()
        let surface = RegressionNotesSurface(items: [
            MemoryItem(key: "note.saved", category: .preference, value: "visible note")
        ])
        let sync = NoteSpotlightSync(flags: flags, index: index, surface: surface)
        await sync.setEnabled(true)
        XCTAssertEqual(index.replaceCount, 1)

        let bus = EventBus()
        sync.follow(bus)
        for _ in 0..<10 {
            await bus.publish(.memoryDidUpdate(itemID: "chat.turn"))
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(index.replaceCount, 1, "conversation updates must not rewrite the notes-only Spotlight index")
    }

    func testChangedNoteSnapshotIsReindexed() async {
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "NoteSpotlightRegression.\(UUID().uuidString)") ?? .standard)
        let index = RegressionNoteIndex()
        let surface = RegressionNotesSurface(items: [
            MemoryItem(key: "note.saved", category: .preference, value: "first version")
        ])
        let sync = NoteSpotlightSync(flags: flags, index: index, surface: surface)
        await sync.setEnabled(true)
        surface.items = [MemoryItem(key: "note.saved", category: .preference, value: "edited version")]
        await sync.sync()
        XCTAssertEqual(index.replaceCount, 2, "edits and deletions must invalidate the indexed snapshot")
    }
}

@MainActor
private final class RegressionNotesSurface: IntelligenceSurface {
    var items: [MemoryItem]
    init(items: [MemoryItem]) { self.items = items }
    func ask(_ query: String) async throws -> String { "" }
    func remember(_ content: String) async {}
    func snapshot(limit: Int) -> [MemoryItem] { Array((snapshotOverride ?? items).prefix(limit)) }
    func noteSnapshot(limit: Int) -> [MemoryItem] { Array(items.prefix(limit)) }
    func switchAspect(to aspect: Aspect) async throws {}
    func statusReport() throws -> String { "" }
}

@available(iOS 17.0, macOS 14.0, *)
private final class RegressionNoteIndex: NoteSearchIndexing {
    private let count = Mutex(0)
    var replaceCount: Int { count.withLock { $0 } }
    func replaceAll(with notes: [MemoryEntity]) async throws { count.withLock { $0 += 1 } }
    func removeAll() async throws {}
}
