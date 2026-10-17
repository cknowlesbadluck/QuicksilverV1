import XCTest
@testable import Quicksilver
import Core

/// MercuryBrain.forgetNote: deletes saved notes, refuses everything else.
@MainActor
final class ForgetNoteBrainTests: XCTestCase {
    func testBrainForgetsANoteButNotAChatTurn() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        await container.brain.remember("Spare key is under the blue pot")
        await container.memoryManager.set(key: "chat.test", value: "an earlier turn", category: .conversation)
        let note = try XCTUnwrap(container.brain.memoryNotes().first { $0.value.contains("Spare key") })
        let chat = try XCTUnwrap(container.memoryManager.items(forPersona: nil).first { $0.key == "chat.test" })

        let refused = await container.brain.forgetNote(id: chat.id)
        XCTAssertFalse(refused)
        XCTAssertTrue(container.memoryManager.items(forPersona: nil).contains { $0.id == chat.id })

        let forgotten = await container.brain.forgetNote(id: note.id)
        XCTAssertTrue(forgotten)
        XCTAssertFalse(container.brain.memoryNotes().contains { $0.id == note.id })

        let again = await container.brain.forgetNote(id: note.id)
        XCTAssertFalse(again)
    }
}
