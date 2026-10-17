import AppIntents
import XCTest
@testable import Core
@testable import QuicksilverIntents

/// "Find in My Notes": notes only, capped, on-device, unlock required (fake-backed surface).
@MainActor
final class FindNotesIntentTests: XCTestCase {
    private var fake: FindNotesSurface!

    override func setUp() async throws {
        fake = FindNotesSurface()
        fake.items = [
            MemoryItem(key: "note.a1", category: .preference, value: "Bike lock code is in the drawer"),
            MemoryItem(key: "note.a2", category: .preference, value: "Bike service due in March"),
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

    func testMatchesNotesOnlyNeverChatOrSystem() {
        let found = fake.memoryNotes(matching: "bike", limit: FindNotesIntent.maxResults).map(MemoryEntity.init)
        XCTAssertEqual(found.map(\.text), ["Bike lock code is in the drawer", "Bike service due in March"])
    }

    func testPerformSucceedsAndNeverAsksTheModel() async throws {
        _ = try await FindNotesIntent(query: "  bike ").perform()
        XCTAssertEqual(fake.askCount, 0, "search must stay a local match, not a model call")
    }

    func testResultsAreCapped() {
        fake.items = (0..<40).map { MemoryItem(key: "note.\($0)", category: .preference, value: "bike \($0)") }
        let found = fake.memoryNotes(matching: "bike", limit: FindNotesIntent.maxResults)
        XCTAssertEqual(found.count, FindNotesIntent.maxResults)
    }

    func testEmptyQueryAsksForValue() async {
        do {
            _ = try await FindNotesIntent(query: "  \n").perform()
            XCTFail("expected needsValue")
        } catch {}
    }

    func testUnconfiguredSurfaceThrows() async {
        IntentDependencies.shared.resetForTesting()
        do {
            _ = try await FindNotesIntent(query: "bike").perform()
            XCTFail("expected cold-start error")
        } catch {}
    }

    func testRequiresUnlockAndStaysInBackground() {
        guard case .requiresAuthentication = FindNotesIntent.authenticationPolicy else {
            return XCTFail("notes are personal: unlock required")
        }
        XCTAssertFalse(FindNotesIntent.openAppWhenRun)
    }

    func testSummary() {
        XCTAssertEqual(FindNotesIntent.summary(for: []), "No saved notes match.")
        let one = MemoryEntity(id: UUID(), text: "Gate code 1234\nsecond line", savedAt: .now)
        XCTAssertEqual(FindNotesIntent.summary(for: [one]), "One note: Gate code 1234")
        XCTAssertTrue(FindNotesIntent.summary(for: [one, one]).hasPrefix("2 notes match."))
    }
}

private final class FindNotesSurface: IntelligenceSurface {
    var items: [MemoryItem] = []
    var askCount = 0
    func ask(_ query: String) async throws -> String { askCount += 1; return "" }
    func remember(_ content: String) async {}
    func snapshot(limit: Int) -> [MemoryItem] { Array(items.prefix(limit)) }
    func switchAspect(to aspect: Aspect) async throws {}
    func statusReport() throws -> String { "" }
}
