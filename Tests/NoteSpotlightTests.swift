import XCTest
@testable import Core
@testable import QuicksilverIntents

@MainActor
final class NoteSpotlightTests: XCTestCase {
    private var flags: FeatureFlags!
    private var index: FakeIndex!
    private var items: [MemoryItem] = []

    override func setUp() async throws {
        flags = FeatureFlags(defaults: UserDefaults(suiteName: "NoteSpotlight.\(UUID().uuidString)") ?? .standard)
        index = FakeIndex()
        items = [
            MemoryItem(key: "note.1", category: .preference, value: "Buy oat milk"),
            MemoryItem(key: "note.2", category: .preference, value: "Call the plumber"),
            MemoryItem(key: "chat.turn", category: .temporary, value: "private chat turn")
        ]
    }

    private func makeSync() -> NoteSpotlightSync {
        let surface = NotesSurface()
        surface.items = items
        return NoteSpotlightSync(flags: flags, index: index, surface: surface)
    }

    func testOffByDefaultAndSyncRemovesEverything() async {
        let sync = makeSync()
        XCTAssertFalse(sync.isEnabled, "Spotlight indexing must be opt-in")
        await sync.sync()
        XCTAssertEqual(index.calls, [.removeAll])
    }

    func testOptInIndexesNotesOnly() async {
        let sync = makeSync()
        await sync.setEnabled(true)
        XCTAssertEqual(index.calls, [.replaceAll(["Buy oat milk", "Call the plumber"])])
        XCTAssertTrue(flags.isEnabled(NoteSpotlightSync.flagKey))
    }

    func testOptOutRemovesIndexedNotes() async {
        let sync = makeSync()
        await sync.setEnabled(true)
        await sync.setEnabled(false)
        XCTAssertEqual(index.calls.last, .removeAll)
        XCTAssertFalse(sync.isEnabled)
    }

    func testIndexFailureIsKeptNotThrown() async {
        index.failNext = true
        let sync = makeSync()
        await sync.setEnabled(true)
        XCTAssertNotNil(sync.lastError)
        await sync.sync()
        XCTAssertNil(sync.lastError, "a later successful sync clears the error")
    }

    func testIndexingIsCapped() async {
        items = (0..<(NoteSpotlightSync.maxIndexed + 25)).map {
            MemoryItem(key: "note.\($0)", category: .preference, value: "n\($0)")
        }
        let sync = makeSync()
        await sync.setEnabled(true)
        guard case .replaceAll(let texts) = index.calls.last else { return XCTFail("expected replaceAll") }
        XCTAssertEqual(texts.count, NoteSpotlightSync.maxIndexed)
    }
}

private final class FakeIndex: NoteSearchIndexing, @unchecked Sendable {
    enum Call: Equatable { case replaceAll([String]), removeAll }
    var calls: [Call] = []
    var failNext = false

    func replaceAll(with notes: [MemoryEntity]) async throws {
        if failNext { failNext = false; throw CocoaError(.fileWriteUnknown) }
        calls.append(.replaceAll(notes.map(\.text)))
    }

    func removeAll() async throws { calls.append(.removeAll) }
}

private final class NotesSurface: IntelligenceSurface {
    var items: [MemoryItem] = []
    func ask(_ query: String) async throws -> String { "" }
    func remember(_ content: String) async {}
    func snapshot(limit: Int) -> [MemoryItem] { Array(items.prefix(limit)) }
    func switchAspect(to aspect: Aspect) async throws {}
    func statusReport() throws -> String { "" }
}
