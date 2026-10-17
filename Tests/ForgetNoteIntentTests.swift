import AppIntents
import XCTest
@testable import Core
@testable import QuicksilverIntents

/// "Forget a Note": confirm first, unlock required, notes only, through IntelligenceSurface.
@MainActor
final class ForgetNoteIntentTests: XCTestCase {
    private var fake: ForgettingSurface!

    override func setUp() async throws {
        fake = ForgettingSurface()
        fake.items = [
            MemoryItem(key: "note.a1", category: .preference, value: "Gate code is 4471\nkeep private"),
            MemoryItem(key: "chat.1", category: .conversation, value: "my bike was stolen")
        ]
        IntentDependencies.shared.resetForTesting()
        IntentDependencies.shared.configure(surface: fake)
    }

    override func tearDown() async throws {
        IntentDependencies.shared.resetForTesting()
        fake = nil
    }

    func testForgetDeletesTheNote() async {
        let note = MemoryEntity(fake.items[0])
        let message = await ForgetNoteIntent.forget(note, using: fake)
        XCTAssertEqual(message, "Forgotten.")
        XCTAssertFalse(fake.items.contains { $0.id == note.id })
        XCTAssertEqual(fake.items.count, 1, "nothing else is touched")
    }

    func testChatTurnCannotBeForgottenThroughTheIntent() async {
        let chat = fake.items[1]
        let disguised = MemoryEntity(id: chat.id, text: chat.value, savedAt: chat.updatedAt)
        let message = await ForgetNoteIntent.forget(disguised, using: fake)
        XCTAssertTrue(message.hasPrefix("That note is already gone"))
        XCTAssertTrue(fake.items.contains { $0.id == chat.id })
    }

    func testForgettingTwiceIsCalm() async {
        let note = MemoryEntity(fake.items[0])
        _ = await ForgetNoteIntent.forget(note, using: fake)
        let again = await ForgetNoteIntent.forget(note, using: fake)
        XCTAssertTrue(again.hasPrefix("That note is already gone"))
    }

    func testConfirmationNamesOnlyTheFirstLine() {
        let note = MemoryEntity(fake.items[0])
        XCTAssertEqual(ForgetNoteIntent.confirmation(for: note), "Forget \"Gate code is 4471\"? This can't be undone.")
    }

    func testRequiresUnlockAndRunsInBackground() {
        guard case .requiresAuthentication = ForgetNoteIntent.authenticationPolicy else {
            return XCTFail("deleting personal notes needs an unlocked device")
        }
        XCTAssertFalse(ForgetNoteIntent.openAppWhenRun)
    }

    /// The system confirmation can't run in a unit test, so guard it at source level:
    /// perform() must ask for confirmation before it calls forget.
    func testPerformConfirmsBeforeDeleting() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Intents/ForgetNoteIntent.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        let confirm = try XCTUnwrap(source.range(of: "try await requestConfirmation("))
        let delete = try XCTUnwrap(source.range(of: "await Self.forget("))
        XCTAssertLessThan(confirm.lowerBound, delete.lowerBound)
    }

    func testConformerWithoutDeletionRefusesByDefault() async {
        let surface: IntelligenceSurface = MinimalSurface()
        let forgotten = await surface.forgetNote(id: UUID())
        XCTAssertFalse(forgotten)
    }

    func testUnconfiguredSurfaceThrows() async {
        IntentDependencies.shared.resetForTesting()
        do {
            _ = try await ForgetNoteIntent(note: MemoryEntity(id: UUID(), text: "x", savedAt: .now)).perform()
            XCTFail("expected cold-start error")
        } catch {}
    }
}

/// Mirrors MercuryBrain.forgetNote: only `note.*` items can be deleted.
private final class ForgettingSurface: IntelligenceSurface {
    var items: [MemoryItem] = []
    func ask(_ query: String) async throws -> String { "" }
    func remember(_ content: String) async {}
    func snapshot(limit: Int) -> [MemoryItem] { Array(items.prefix(limit)) }
    func switchAspect(to aspect: Aspect) async throws {}
    func statusReport() throws -> String { "" }
    func forgetNote(id: UUID) async -> Bool {
        guard memoryNote(id: id) != nil else { return false }
        items.removeAll { $0.id == id }
        return memoryNote(id: id) == nil
    }
}

/// Implements only the pre-#343 requirements: proves `forgetNote` is additive and fails closed.
@MainActor
private final class MinimalSurface: IntelligenceSurface {
    func ask(_ query: String) async throws -> String { "" }
    func remember(_ content: String) async {}
    func snapshot(limit: Int) -> [MemoryItem] { [] }
    func switchAspect(to aspect: Aspect) async throws {}
    func statusReport() throws -> String { "" }
}
