import Synchronization
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

    private func makeSync(waitForMemoryLoad: Bool = false) -> NoteSpotlightSync {
        let surface = NotesSurface()
        surface.items = items
        return NoteSpotlightSync(flags: flags, index: index, surface: surface, waitForMemoryLoad: waitForMemoryLoad)
    }

    func testNotesBehindManyTurnsAreStillFound() {
        let surface = NotesSurface()
        surface.items = (0..<600).map {
            MemoryItem(key: "turn.\($0)", category: .conversation, value: "turn \($0)")
        } + [MemoryItem(key: "note.late", category: .preference, value: "Buried note")]
        XCTAssertEqual(surface.memoryNotes().map(\.value), ["Buried note"], "cap must apply after filtering")
        XCTAssertEqual(surface.memoryNotes(matching: "buried").count, 1)
    }

    func testOptOutRemovalFailureIsFlaggedThenRetried() async {
        let sync = makeSync()
        await sync.setEnabled(true)
        index.failNext = true
        await sync.setEnabled(false)
        XCTAssertTrue(sync.removalFailed, "a failed opt-out must be visible, not silent")
        await sync.sync()
        XCTAssertFalse(sync.removalFailed)
        XCTAssertEqual(index.calls.last, .removeAll)
    }

    func testRapidToggleEndsConsistentWithFlag() async {
        let sync = makeSync()
        for _ in 0..<5 {
            async let on: Void = sync.setEnabled(true)
            async let off: Void = sync.setEnabled(false)
            _ = await (on, off)
            let expectRemoved = !sync.isEnabled
            XCTAssertEqual(index.calls.last == .removeAll, expectRemoved)
        }
        await sync.setEnabled(false)
        XCTAssertEqual(index.calls.last, .removeAll)
    }

    func testColdLaunchWaitsForMemoryLoadBeforeIndexing() async {
        flags.set(NoteSpotlightSync.flagKey, enabled: true)
        let sync = makeSync(waitForMemoryLoad: true)
        await sync.sync()
        XCTAssertEqual(index.calls, [], "an unloaded snapshot must not replace the index")
        await sync.memoryDidLoad()
        XCTAssertEqual(index.calls, [.replaceAll(["Buy oat milk", "Call the plumber"])])
    }

    func testLaterSuccessfulLoadReleasesTheGateOnce() async {
        flags.set(NoteSpotlightSync.flagKey, enabled: true)
        let sync = makeSync(waitForMemoryLoad: true)
        await sync.sync()
        XCTAssertEqual(index.calls, [], "the failed cold-launch load never released the gate")
        await sync.memoryLoadSucceeded()
        XCTAssertEqual(index.calls, [.replaceAll(["Buy oat milk", "Call the plumber"])])
        await sync.memoryLoadSucceeded()
        XCTAssertEqual(index.calls.count, 1, "an already-ready gate does not reconcile again")
    }

    func testColdLaunchOptedOutStillRemovesBeforeLoad() async {
        let sync = makeSync(waitForMemoryLoad: true)
        await sync.sync()
        XCTAssertEqual(index.calls, [.removeAll])
    }

    func testMemoryUpdateResyncsWhileOptedIn() async throws {
        let sync = makeSync()
        await sync.setEnabled(true)
        let bus = EventBus()
        sync.follow(bus)
        for _ in 0..<200 where index.calls.count < 2 {
            await bus.publish(.memoryDidUpdate(itemID: "note.1"))
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertGreaterThanOrEqual(index.calls.count, 2, "a note change must re-sync Spotlight")
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

/// Checked Sendable via `Mutex` (issue #252 ratchet).
private final class FakeIndex: NoteSearchIndexing {
    enum Call: Equatable, Sendable { case replaceAll([String]), removeAll }
    private struct State {
        var calls: [Call] = []
        var failNext = false
    }
    private let state = Mutex(State())

    var calls: [Call] { state.withLock { $0.calls } }
    var failNext: Bool {
        get { state.withLock { $0.failNext } }
        set { state.withLock { $0.failNext = newValue } }
    }

    func replaceAll(with notes: [MemoryEntity]) async throws {
        let texts = notes.map(\.text)
        let shouldFail = state.withLock { current -> Bool in
            if current.failNext {
                current.failNext = false
                return true
            }
            current.calls.append(.replaceAll(texts))
            return false
        }
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
    }

    func removeAll() async throws {
        let shouldFail = state.withLock { current -> Bool in
            if current.failNext {
                current.failNext = false
                return true
            }
            current.calls.append(.removeAll)
            return false
        }
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
    }
}

private final class NotesSurface: IntelligenceSurface {
    var items: [MemoryItem] = []
    func ask(_ query: String) async throws -> String { "" }
    func remember(_ content: String) async {}
    func snapshot(limit: Int) -> [MemoryItem] { Array(items.prefix(limit)) }
    func switchAspect(to aspect: Aspect) async throws {}
    func statusReport() throws -> String { "" }
}
