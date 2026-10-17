import XCTest
@testable import Quicksilver
import Core
import ServicesAI

/// MercuryBrain.noteSummary: notes only, through the injected on-device summarizer.
@MainActor
final class NoteSummaryBrainTests: XCTestCase {
    func testSummarizesNotesButNotChatTurns() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        await container.brain.remember("Spare key is under the blue pot by the back door")
        await container.memoryManager.set(key: "chat.test", value: "an earlier turn", category: .conversation)
        let note = try XCTUnwrap(container.brain.memoryNotes().first { $0.value.contains("Spare key") })
        let chat = try XCTUnwrap(container.memoryManager.items(forPersona: nil).first { $0.key == "chat.test" })
        let fake = EchoSummarizer()

        let summary = await container.brain.noteSummary(id: note.id, using: fake)
        XCTAssertEqual(summary, "summary of: \(note.value)")

        let refused = await container.brain.noteSummary(id: chat.id, using: fake)
        XCTAssertNil(refused)
        let missing = await container.brain.noteSummary(id: UUID(), using: fake)
        XCTAssertNil(missing)
    }

    func testDefaultSummarizerIsNilWithoutTheOnDeviceModel() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        await container.brain.remember(String(repeating: "Long note about the garden plan. ", count: 6))
        let note = try XCTUnwrap(container.brain.memoryNotes().first)
        if container.aiService.onDeviceProvider?.isAvailable != true {
            let summary = await container.brain.noteSummary(id: note.id)
            XCTAssertNil(summary, "no on-device model means no summary, never a cloud call")
        }
    }
}

private struct EchoSummarizer: NoteSummarizing {
    func summary(of note: String) async -> String? { "summary of: \(note)" }
}
