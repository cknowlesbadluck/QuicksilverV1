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

    func testSystemFactoryNeverCrashesAndExplainsItself() {
        let model = SystemOnDeviceModel.make()
        XCTAssertFalse(model.availability.userFacingReason.isEmpty)
    }
}

private final class FakeOnDeviceModel: OnDeviceLanguageModel {
    struct Call: Sendable { let instructions: String?; let prompt: String }
    let availability: OnDeviceModelAvailability
    let reply: String
    private let recorded = Mutex<[Call]>([])
    var calls: [Call] { recorded.withLock { $0 } }

    init(availability: OnDeviceModelAvailability, reply: String) {
        self.availability = availability
        self.reply = reply
    }

    func respond(instructions: String?, prompt: String) async throws -> String {
        recorded.withLock { $0.append(Call(instructions: instructions, prompt: prompt)) }
        return reply
    }
}
