import XCTest
@testable import Core
@testable import QuicksilverIntents

/// M3.5-T11: MemoryEntity exposes user notes only, through IntelligenceSurface (fake-backed).
@MainActor
final class MemoryEntityTests: XCTestCase {
    private var fake: NotesSurface!

    override func setUp() async throws {
        fake = NotesSurface()
        fake.items = [
            MemoryItem(key: "note.a1", category: .preference, value: "Bike lock code is in the drawer"),
            MemoryItem(key: "note.brain.b2", category: .preference, value: "Mum's birthday is 3 May"),
            MemoryItem(key: "chat.1", category: .conversation, value: "my bike was stolen"),
            MemoryItem(key: "system.x", category: .system, value: "bike telemetry")
        ]
        IntentDependencies.shared.resetForTesting()
        IntentDependencies.shared.configure(surface: fake)
    }

    override func tearDown() async throws {
        IntentDependencies.shared.resetForTesting()
        fake = nil
    }

    func testSuggestedEntitiesAreNotesOnly() async throws {
        let entities = try await MemoryEntityQuery().suggestedEntities()
        XCTAssertEqual(Set(entities.map(\.text)), ["Bike lock code is in the drawer", "Mum's birthday is 3 May"])
    }

    func testStringMatchNeverReturnsChatOrSystem() async throws {
        let entities = try await MemoryEntityQuery().entities(matching: "BIKE")
        XCTAssertEqual(entities.map(\.text), ["Bike lock code is in the drawer"])
    }

    func testLookupByIdentifierSkipsNonNotes() async throws {
        let chatID = fake.items[2].id
        let noteID = fake.items[0].id
        let entities = try await MemoryEntityQuery().entities(for: [noteID, chatID, UUID()])
        XCTAssertEqual(entities.map(\.id), [noteID])
    }

    func testTitleIsFirstLineTruncated() {
        XCTAssertEqual(MemoryEntity.title(for: "short\nsecond"), "short")
        let long = String(repeating: "a", count: 80)
        XCTAssertEqual(MemoryEntity.title(for: long).count, 60)
        XCTAssertTrue(MemoryEntity.title(for: long).hasSuffix("…"))
    }

    func testUnconfiguredSurfaceThrows() async {
        IntentDependencies.shared.resetForTesting()
        do {
            _ = try await MemoryEntityQuery().suggestedEntities()
            XCTFail("expected cold-start error")
        } catch {}
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
