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
}

private final class RegressionNotesSurface: IntelligenceSurface {
    let items: [MemoryItem]
    init(items: [MemoryItem]) { self.items = items }
    func ask(_ query: String) async throws -> String { "" }
    func remember(_ content: String) async {}
    func snapshot(limit: Int) -> [MemoryItem] { Array(items.prefix(limit)) }
    func switchAspect(to aspect: Aspect) async throws {}
    func statusReport() throws -> String { "" }
}

@available(iOS 17.0, macOS 14.0, *)
private final class RegressionNoteIndex: NoteSearchIndexing {
    private(set) var replaceCount = 0
    func replaceAll(with notes: [MemoryEntity]) async throws { replaceCount += 1 }
    func removeAll() async throws {}
}
