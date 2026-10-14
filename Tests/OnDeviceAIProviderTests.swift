import Synchronization
import XCTest
import Core
@testable import ServicesAI

/// M3.5-T1/T2: the on-device provider behind `AIProvider`, driven by a fake model.
final class OnDeviceAIProviderTests: XCTestCase {
    func testAvailableModelAnswersAndNeverTrains() async throws {
        let model = FakeOnDeviceModel(availability: .available, reply: "Landed.")
        let provider = OnDeviceAIProvider(model: model)
        XCTAssertTrue(provider.isAvailable)
        XCTAssertFalse(provider.trainsOnPrompts)

        let request = AIRequest(prompt: "plan the shelf", systemPrompt: "You are Mercury.")
        let response = try await provider.complete(request)
        XCTAssertEqual(response.content, "Landed.")
        let call = try XCTUnwrap(model.calls.first)
        XCTAssertEqual(call.instructions, "You are Mercury.")
        XCTAssertTrue(call.prompt.hasSuffix("user: plan the shelf"))
    }

    func testUnavailableModelThrowsTypedReason() async {
        for reason in [OnDeviceModelAvailability.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unsupportedOS] {
            let provider = OnDeviceAIProvider(model: FakeOnDeviceModel(availability: reason, reply: ""))
            XCTAssertFalse(provider.isAvailable)
            XCTAssertFalse(reason.userFacingReason.isEmpty)
            do {
                _ = try await provider.complete(AIRequest(prompt: "hi"))
                XCTFail("Expected unavailable for \(reason)")
            } catch {
                XCTAssertEqual(error as? OnDeviceModelError, .unavailable(reason))
            }
        }
    }

    func testOldestHistoryDroppedToFitCompactBudget() async throws {
        let model = FakeOnDeviceModel(availability: .available, reply: "ok")
        let provider = OnDeviceAIProvider(model: model)
        let big = String(repeating: "x", count: OnDeviceAIProvider.maxPromptCharacters / 2)
        let history = [Message(role: .user, content: "old-\(big)"), Message(role: .assistant, content: "new-\(big)")]
        _ = try await provider.complete(AIRequest(prompt: "now", history: history))
        let prompt = try XCTUnwrap(model.calls.first?.prompt)
        XCTAssertLessThanOrEqual(prompt.count, OnDeviceAIProvider.maxPromptCharacters)
        XCTAssertFalse(prompt.contains("old-"))
        XCTAssertTrue(prompt.hasSuffix("user: now"))
    }

    func testOversizedPromptIsRejectedNotTruncatedSilently() async {
        let provider = OnDeviceAIProvider(model: FakeOnDeviceModel(availability: .available, reply: "ok"))
        let huge = String(repeating: "y", count: OnDeviceAIProvider.maxPromptCharacters + 1)
        do {
            _ = try await provider.complete(AIRequest(prompt: huge))
            XCTFail("Expected contextWindowExceeded")
        } catch {
            XCTAssertEqual(error as? OnDeviceModelError, .contextWindowExceeded)
        }
    }

    func testContextOverflowRetriesOnceWithMinimalPrompt() async throws {
        let model = FakeOnDeviceModel(availability: .available, reply: "ok", overflowFirst: true)
        let provider = OnDeviceAIProvider(model: model)
        let history = [Message(role: .user, content: "earlier"), Message(role: .assistant, content: "reply")]
        let response = try await provider.complete(AIRequest(prompt: "now", history: history))
        XCTAssertEqual(response.content, "ok")
        XCTAssertEqual(model.calls.count, 2)
        XCTAssertTrue(model.calls[0].prompt.contains("earlier"))
        XCTAssertEqual(model.calls[1].prompt, "user: now")
    }

    func testInstructionsAreCappedToBudget() async throws {
        let model = FakeOnDeviceModel(availability: .available, reply: "ok")
        let provider = OnDeviceAIProvider(model: model)
        let long = String(repeating: "i", count: OnDeviceAIProvider.maxInstructionCharacters * 2)
        _ = try await provider.complete(AIRequest(prompt: "q", systemPrompt: long))
        XCTAssertEqual(model.calls.first?.instructions?.count, OnDeviceAIProvider.maxInstructionCharacters)
    }

    func testCapKeepsTrailingPlainDirective() {
        let text = String(repeating: "c", count: OnDeviceAIProvider.maxInstructionCharacters) + "\nPlain mode: no wit."
        let capped = OnDeviceAIProvider.cappedInstructions(text)
        XCTAssertLessThanOrEqual(capped.count, OnDeviceAIProvider.maxInstructionCharacters)
        XCTAssertTrue(capped.hasSuffix("Plain mode: no wit."))
        XCTAssertTrue(capped.hasPrefix("ccc"))
    }

    func testPrewarmOnlyWhenAvailable() {
        let ready = FakeOnDeviceModel(availability: .available, reply: "")
        OnDeviceAIProvider(model: ready).prewarm(instructions: "x")
        XCTAssertEqual(ready.prewarms, 1)
        let off = FakeOnDeviceModel(availability: .modelNotReady, reply: "")
        OnDeviceAIProvider(model: off).prewarm(instructions: "x")
        XCTAssertEqual(off.prewarms, 0)
    }

    @MainActor
    func testOnDeviceRequestPrefersLocalHistoryCappedToFourPairs() {
        let local = (0..<12).map { Message(role: $0.isMultiple(of: 2) ? .user : .assistant, content: "m\($0)") }
        let cloud = [Message(role: .user, content: "cloud-only")]
        let request = AIRequest(prompt: "q", history: cloud, onDeviceHistory: local)
        let compact = AIService.onDeviceRequest(from: request)
        XCTAssertEqual(compact.history.map(\.content), (4..<12).map { "m\($0)" })
    }

    func testSystemFactoryNeverCrashesAndExplainsItself() {
        let model = SystemOnDeviceModel.make()
        XCTAssertFalse(model.availability.userFacingReason.isEmpty)
    }
}

private final class FakeOnDeviceModel: OnDeviceLanguageModel {
    struct Call: Sendable { let instructions: String?; let prompt: String }
    let availability: OnDeviceModelAvailability
    let reply: String
    let overflowFirst: Bool
    private let recorded = Mutex<[Call]>([])
    private let warmed = Mutex(0)
    var calls: [Call] { recorded.withLock { $0 } }
    var prewarms: Int { warmed.withLock { $0 } }

    init(availability: OnDeviceModelAvailability, reply: String, overflowFirst: Bool = false) {
        self.availability = availability
        self.reply = reply
        self.overflowFirst = overflowFirst
    }

    func prewarm(instructions: String?) { warmed.withLock { $0 += 1 } }

    func respond(instructions: String?, prompt: String) async throws -> String {
        let count = recorded.withLock { calls in
            calls.append(Call(instructions: instructions, prompt: prompt))
            return calls.count
        }
        if overflowFirst, count == 1 { throw OnDeviceModelError.contextWindowExceeded }
        return reply
    }
}
