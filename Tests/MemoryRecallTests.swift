import XCTest
@testable import Core
@testable import Memory

final class MemoryRecallTests: XCTestCase {
    private func note(_ value: String, ageDays: Double = 0) -> MemoryItem {
        let date = Date(timeIntervalSince1970: 1_000_000 - ageDays * 86_400)
        return MemoryItem(key: "note.\(UUID())", category: .temporary, value: value, createdAt: date, updatedAt: date)
    }

    func testDetectsRecallPhrasings() {
        XCTAssertEqual(MemoryRecall.topic(in: "What did I tell you about my bike?"), "my bike")
        XCTAssertEqual(MemoryRecall.topic(in: "what do you remember about Lisbon"), "lisbon")
        XCTAssertNil(MemoryRecall.topic(in: "tell me about bikes"))
    }

    func testConfidentMatchQuotesTheNote() throws {
        let notes = [note("My bike is a blue Brompton")]
        let answer = try XCTUnwrap(MemoryRecall.answer(to: "What did I tell you about my bike?", from: notes))
        XCTAssertEqual(answer.text, "You told me: “My bike is a blue Brompton”")
    }

    func testLowConfidenceFallsBackToModel() {
        XCTAssertNil(MemoryRecall.answer(to: "what did I tell you about my blue car", from: [note("My bike is blue")]),
                     "Every topic word must match; otherwise the model answers")
        XCTAssertNil(MemoryRecall.answer(to: "what did I tell you about it", from: [note("anything")]), "Stopword-only topic")
    }

    func testIgnoresConversationTurnsAndCapsQuotes() throws {
        let turn = MemoryItem(key: "chat.1", category: .conversation, value: "what did I tell you about tea")
        XCTAssertNil(MemoryRecall.answer(to: "what did I tell you about tea", from: [turn]))
        let notes = (0..<5).map { note("tea fact \($0)", ageDays: Double($0)) }
        let answer = try XCTUnwrap(MemoryRecall.answer(to: "what did I say about tea", from: notes))
        XCTAssertEqual(answer.itemIDs.count, MemoryRecall.maxQuoted)
        XCTAssertEqual(answer.itemIDs.first, notes[0].id, "Newest first")
    }
}
