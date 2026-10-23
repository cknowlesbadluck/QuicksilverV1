import XCTest
@testable import Quicksilver
import Core
import ServicesAI

/// Memory screen: on-device note summaries (#345) appear under the note, notes only.
@MainActor
final class MemoryNoteSummaryTests: XCTestCase {
    private let longNote = String(repeating: "Garden plan: tomatoes by the fence, herbs near the door. ", count: 3)

    func testSummarizeStoresTheSummaryForThatNote() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)
        await vm.addQuickNote(longNote)
        let note = try XCTUnwrap(vm.items.first)

        await vm.summarize(id: note.id, using: FixedSummarizer(text: "Garden layout."))
        XCTAssertEqual(vm.summaries[note.id], "Garden layout.")
    }

    func testUnavailableSummaryLeavesNoteUntouchedAndSaysWhy() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)
        await vm.addQuickNote(longNote)
        let note = try XCTUnwrap(vm.items.first)

        await vm.summarize(id: note.id, using: FixedSummarizer(text: nil))
        XCTAssertNil(vm.summaries[note.id])
        XCTAssertEqual(vm.statusMessage, "Summary unavailable on this device")
    }

    func testShortNotesAndChatTurnsAreNotOffered() async throws {
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = MemoryViewModel(container: container)
        await vm.addQuickNote("Buy milk")
        let short = try XCTUnwrap(vm.items.first)
        XCTAssertFalse(vm.canSummarize(short))

        let chat = MemoryItem(key: "chat.1", category: .conversation, value: longNote)
        XCTAssertFalse(vm.canSummarize(chat))
    }
}

private struct FixedSummarizer: NoteSummarizing {
    let text: String?
    func summary(of note: String) async -> String? { text }
}
