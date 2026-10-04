import XCTest
import Core
@testable import ServicesAI

final class CloudContextPolicyTests: XCTestCase {
    func testTrainsOnPromptsForcesMinimal() {
        XCTAssertEqual(
            CloudContextPolicy.resolvedLevel(requested: .standard, trainsOnPrompts: true),
            .minimal
        )
        XCTAssertEqual(
            CloudContextPolicy.resolvedLevel(requested: .standard, trainsOnPrompts: false),
            .standard
        )
    }

    func testMinimalDropsMemoriesAndDeviceLine() {
        let blocks = CloudContextPolicy.assemble(
            question: "what next",
            recentTurns: ["one", "two", "three"],
            memories: [note("keep me")],
            coarseDeviceLine: "battery low",
            requested: .standard,
            trainsOnPrompts: true
        )
        XCTAssertEqual(blocks.map(\.kind), [.question, .turn, .turn])
        XCTAssertEqual(blocks.map(\.text), ["what next", "two", "three"])
        XCTAssertFalse(blocks.contains { $0.kind == .memory || $0.kind == .device })
    }

    func testStandardCapsTurnsMemoriesAndDeviceLine() {
        let memories = [
            note(String(repeating: "a", count: 200)),
            note("second"),
            note("third"),
            note("fourth")
        ]
        let blocks = CloudContextPolicy.assemble(
            question: "plan",
            recentTurns: ["t1", "t2", "t3", "t4", "t5"],
            memories: memories,
            coarseDeviceLine: "battery low",
            requested: .standard,
            trainsOnPrompts: false
        )
        let turns = blocks.filter { $0.kind == .turn }
        let notes = blocks.filter { $0.kind == .memory }
        XCTAssertEqual(turns.map(\.text), ["t2", "t3", "t4", "t5"])
        XCTAssertEqual(notes.count, 3)
        XCTAssertEqual(notes[0].text.count, CloudContextPolicy.memoryCharCap)
        XCTAssertEqual(blocks.last?.text, "battery low")
    }

    func testPrivateAndKeyLikeMemoriesNeverLeave() {
        var privateNote = note("secret thought")
        privateNote.metadata["private"] = "true"
        let keyNote = MemoryItem(key: "api.token.backup", category: .system, value: "nope")
        let blocks = CloudContextPolicy.assemble(
            question: "q",
            recentTurns: [],
            memories: [privateNote, keyNote, note("ok")],
            coarseDeviceLine: "nexus diagnostic 42",
            requested: .standard,
            trainsOnPrompts: false
        )
        XCTAssertEqual(blocks.map(\.text), ["q", "ok"])
    }

    private func note(_ value: String) -> MemoryItem {
        MemoryItem(key: "note.\(value.prefix(8))", category: .temporary, value: value)
    }
}
