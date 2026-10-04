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
            CloudContextInput(
                question: "what next",
                recentTurns: ["one", "two", "three"],
                memories: [note("keep me")],
                coarseDeviceLine: "battery low"
            ),
            level: .minimal
        )
        XCTAssertEqual(blocks.map(\.kind), [.question])
        XCTAssertEqual(blocks.map(\.text), ["what next"])
        XCTAssertFalse(blocks.contains { $0.kind == .memory || $0.kind == .device })
    }

    func testStandardCapsMemoriesAndDeviceLine() {
        let memories = [
            note(String(repeating: "a", count: 200)),
            note("second"),
            note("third"),
            note("fourth")
        ]
        let blocks = CloudContextPolicy.assemble(
            CloudContextInput(
                question: "plan",
                recentTurns: ["t1", "t2", "t3", "t4", "t5"],
                memories: memories,
                coarseDeviceLine: "battery low"
            ),
            level: .standard
        )
        let notes = blocks.filter { $0.kind == .memory }
        XCTAssertEqual(blocks.first?.kind, .question)
        XCTAssertFalse(blocks.contains { $0.kind == .turn })
        XCTAssertEqual(notes.count, 3)
        XCTAssertEqual(notes[0].text.count, CloudContextPolicy.memoryCharCap)
        XCTAssertEqual(blocks.last?.text, "battery low")
    }

    func testPrivateFlagVariantsNeverLeave() {
        for flag in ["true", "1", "yes", "TRUE", "Yes", "YES"] {
            var privateNote = note("secret thought \(flag)")
            privateNote.metadata["private"] = flag
            let blocks = CloudContextPolicy.assemble(
                CloudContextInput(
                    question: "q",
                    memories: [privateNote, note("ok-\(flag)")]
                ),
                level: .standard
            )
            XCTAssertEqual(
                blocks.map(\.text),
                ["q", "ok-\(flag)"],
                "private flag \(flag) must drop the note"
            )
        }
    }

    func testCredentialKeySegmentsNotSubstrings() {
        let keyNote = MemoryItem(key: "api.token.backup", category: .system, value: "nope")
        let keyboard = MemoryItem(
            key: "preference.keyboard.layout",
            category: .preference,
            value: "qwerty"
        )
        let monkey = MemoryItem(
            key: "note.monkey_behavior",
            category: .temporary,
            value: "curious"
        )
        let blocks = CloudContextPolicy.assemble(
            CloudContextInput(
                question: "q",
                memories: [keyNote, keyboard, monkey],
                coarseDeviceLine: "Christopher iPhone"
            ),
            level: .standard
        )
        XCTAssertEqual(blocks.map(\.text), ["q", "qwerty", "curious"])
    }

    func testCredentialValuesNeverLeave() {
        let leak = note("my API token is sk-abcdefghijklmnopqrstuvwxyz")
        let plain = note("API token: abcdefghijklmnopqrstuvwxyz")
        let passwordAssign = note("password = hunter2")
        let tokenAssign = note("token = abcdefghijklmnopqrstuvwxyz")
        let apiKeyAssign = note("api_key = abcdefghijklmnopqrstuvwxyz")
        let secretAssign = note("secret = hunter2")
        let bearerAssign = note("bearer = abcdefghijklmnopqrstuvwxyz")
        let blocks = CloudContextPolicy.assemble(
            CloudContextInput(
                question: "q",
                memories: [
                    leak, plain, passwordAssign, tokenAssign,
                    apiKeyAssign, secretAssign, bearerAssign, note("safe")
                ]
            ),
            level: .standard
        )
        XCTAssertEqual(blocks.map(\.text), ["q", "safe"])
    }

    func testRedactForTrainingProviderStripsAppendixAndContext() {
        let appendix = CloudContextPolicy.systemAppendix(from: [
            GatewayContextBlock(kind: .memory, text: "tea preference", privacy: .device),
            GatewayContextBlock(kind: .device, text: "battery low", privacy: .device)
        ])
        let system = "You are Mercury.\n\n" + appendix
        let request = AIRequest(
            prompt: "hello",
            systemPrompt: system,
            history: [
                Message(role: .user, content: "u1"),
                Message(role: .assistant, content: "a1")
            ],
            context: [
                GatewayContextBlock(kind: .memory, text: "tea preference", privacy: .device),
                GatewayContextBlock(kind: .device, text: "battery low", privacy: .device)
            ]
        )
        let redacted = CloudContextPolicy.redactForTrainingProvider(request)
        XCTAssertEqual(redacted.systemPrompt, "You are Mercury.")
        XCTAssertTrue(redacted.context.isEmpty)
        XCTAssertEqual(redacted.history.map(\.content), ["u1", "a1"])
        XCTAssertFalse((redacted.systemPrompt ?? "").contains("tea preference"))
        XCTAssertFalse((redacted.systemPrompt ?? "").contains("battery low"))
    }

    func testDeviceAllowlistAndThermalPriority() {
        XCTAssertNil(CloudContextPolicy.sanitizedDeviceLine("Christopher iPhone"))
        XCTAssertEqual(CloudContextPolicy.sanitizedDeviceLine("battery low"), "battery low")
        XCTAssertEqual(
            CloudContextPolicy.coarseDeviceLine(
                batteryLevel: 0.8,
                thermalState: "critical",
                lowPowerMode: true
            ),
            "thermal critical"
        )
        XCTAssertEqual(
            CloudContextPolicy.coarseDeviceLine(
                batteryLevel: 0.1,
                thermalState: "nominal",
                lowPowerMode: false
            ),
            "battery critical"
        )
    }

    func testGatewayContextOmitsQuestionAndTurns() {
        let blocks = CloudContextPolicy.assemble(
            CloudContextInput(
                question: "q",
                recentTurns: ["u", "a"],
                memories: [note("m")],
                coarseDeviceLine: "thermal fair"
            ),
            level: .standard
        )
        let context = CloudContextPolicy.gatewayContext(from: blocks)
        XCTAssertEqual(context.map(\.kind), [.memory, .device])
        XCTAssertEqual(context.map(\.text), ["m", "thermal fair"])
    }

    func testCappedHistoryUsesPairs() {
        let history = (1...6).flatMap { index -> [Message] in
            [
                Message(role: .user, content: "u\(index)"),
                Message(role: .assistant, content: "a\(index)")
            ]
        }
        let minimal = CloudContextPolicy.cappedHistory(history, level: .minimal)
        XCTAssertEqual(minimal.map(\.content), ["u5", "a5", "u6", "a6"])
        let standard = CloudContextPolicy.cappedHistory(history, level: .standard)
        XCTAssertEqual(standard.count, 8)
        XCTAssertEqual(standard.first?.content, "u3")
    }

    func testShareableMemoriesBackfillsAfterPrivate() {
        var privateNote = note("hidden")
        privateNote.metadata["private"] = "true"
        let items = [privateNote, note("one"), note("two"), note("three"), note("four")]
        let kept = CloudContextPolicy.shareableMemories(items, cap: 3)
        XCTAssertEqual(kept.map(\.value), ["one", "two", "three"])
    }

    private func note(_ value: String) -> MemoryItem {
        MemoryItem(key: "note.\(value.prefix(8))", category: .temporary, value: value)
    }
}
