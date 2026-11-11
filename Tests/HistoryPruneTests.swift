import Synchronization
import XCTest
@testable import Core
@testable import ServicesAI

/// Cloud fallback prunes personal history instead of blocking the whole turn. Privacy floor:
/// whatever goes out must plan `.cloudEligible`, and no outbound history turn is personal.
final class HistoryPruneTests: XCTestCase {
    private let question = "What is the capital of Peru?"

    private func conversation(around personal: String) -> [Message] {
        [
            Message(role: .user, content: personal),
            Message(role: .assistant, content: "That sounds hard. Want to talk it through?"),
            Message(role: .user, content: "Explain the difference between TCP and UDP"),
            Message(role: .assistant, content: "TCP is connection-oriented and reliable; UDP is not.")
        ]
    }

    func testEligibleRequestIsSentUnchanged() throws {
        let request = AIRequest(prompt: question, history: conversation(around: "Explain recursion briefly"))
        let outbound = try XCTUnwrap(CloudContextPolicy.cloudFallbackRequest(request))
        XCTAssertEqual(outbound.history.map(\.content), request.history.map(\.content))
        XCTAssertEqual(outbound.id, request.id)
    }

    /// Corpus from #340: after any personal turn, a knowledge question still reaches the cloud,
    /// the personal turn and the reply to it are gone, and the impersonal pair is kept.
    func testPersonalCorpusTurnsArePrunedNotBlocking() throws {
        let personal = PrivacyCorpus.personal.map(\.text) + PrivacyCorpus.heldOutPersonal
        for text in personal where CloudContextPolicy.isPersonalText(text) {
            let request = AIRequest(prompt: question, history: conversation(around: text))
            XCTAssertEqual(CloudContextPolicy.plan(request), .localOnly(reason: "personal"), text)
            let outbound = try XCTUnwrap(CloudContextPolicy.cloudFallbackRequest(request), text)
            XCTAssertEqual(outbound.history.map(\.content), Array(request.history.suffix(2)).map(\.content), text)
            XCTAssertTrue(CloudContextPolicy.plan(outbound).isCloudEligible, text)
        }
    }

    /// The floor, over the whole corpus: no outbound history turn is ever personal.
    func testNoOutboundHistoryTurnIsPersonal() {
        let all = PrivacyCorpus.personal.map(\.text) + PrivacyCorpus.heldOutPersonal
            + PrivacyCorpus.impersonalSelfReferential + PrivacyCorpus.heldOutImpersonalSelfReferential
        for text in all {
            guard let outbound = CloudContextPolicy.cloudFallbackRequest(
                AIRequest(prompt: question, history: conversation(around: text))
            ) else { continue }
            let leaked = outbound.history.filter { CloudContextPolicy.isPersonalText($0.content) }
            XCTAssertTrue(leaked.isEmpty, "personal history left the device: \(leaked.map(\.content))")
        }
    }

    func testPersonalAssistantTurnTakesTheQuestionBeforeIt() {
        let history = [
            Message(role: .user, content: "what did you note earlier"),
            Message(role: .assistant, content: "You said your doctor changed your medication."),
            Message(role: .user, content: "Explain recursion"),
            Message(role: .assistant, content: "A function calling itself.")
        ]
        XCTAssertEqual(CloudContextPolicy.prunedHistory(history).map(\.content), ["Explain recursion", "A function calling itself."])
    }

    func testFloorStillKeepsTheseLocal() {
        let personalHistory = conversation(around: "my rent went up again")
        let local: [AIRequest] = [
            // The prompt itself is personal or first-person.
            AIRequest(prompt: "what should I tell my doctor", history: personalHistory),
            AIRequest(prompt: "how do I fix my budget", history: personalHistory),
            // Follow-ups that only make sense with the pruned turn aren't knowledge questions.
            AIRequest(prompt: "and then?", history: personalHistory),
            // Memory context and the explicit personal flag are not history: never pruned away.
            AIRequest(prompt: question, history: personalHistory,
                      context: [GatewayContextBlock(kind: .memory, text: "rent note", privacy: .cloud)]),
            AIRequest(prompt: question, history: personalHistory, metadata: [CloudContextPolicy.personalTurnKey: "1"])
        ]
        for request in local {
            XCTAssertNil(CloudContextPolicy.cloudFallbackRequest(request), request.prompt)
        }
    }

    func testNothingToPruneStaysLocal() {
        XCTAssertNil(CloudContextPolicy.cloudFallbackRequest(AIRequest(prompt: "lol ok")))
    }
}

/// End to end through AIService: on-device fails, the cloud gets the pruned history.
@MainActor
final class HistoryPruneRoutingTests: XCTestCase {
    func testOnDeviceFailureSendsPrunedHistoryToCloud() async throws {
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "HistoryPrune.\(UUID().uuidString)") ?? .standard)
        flags.set("aiServiceEnabled", enabled: true)
        let cloud = RecordingCloud()
        let service = AIService(primary: cloud, secondary: nil, eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        service.onDeviceProvider = OnDeviceAIProvider(
            model: ScriptedOnDeviceModel(availability: .available, outcome: .fail(.generationFailed("x")))
        )
        service.retrySleep = { _ in }
        let request = AIRequest(prompt: "What is the capital of Peru?", history: [
            Message(role: .user, content: "how much is in my bank account"),
            Message(role: .assistant, content: "I can't see that."),
            Message(role: .user, content: "Explain recursion"),
            Message(role: .assistant, content: "A function calling itself.")
        ])

        let response = try await service.complete(request)

        XCTAssertEqual(response.content, "cloud")
        let sent = try XCTUnwrap(cloud.requests.first)
        XCTAssertFalse(sent.history.contains { $0.content.contains("bank account") }, "personal turn left the device")
        XCTAssertFalse(sent.history.contains { $0.content == "I can't see that." }, "its reply left the device")
        XCTAssertTrue(sent.history.contains { $0.content == "Explain recursion" })
    }
}

private final class RecordingCloud: AIProvider {
    let id = "cloud"
    let displayName = "Cloud"
    let isAvailable = true
    private let recorded = Mutex<[AIRequest]>([])
    var requests: [AIRequest] { recorded.withLock { $0 } }
    func complete(_ request: AIRequest) async throws -> AIResponse {
        recorded.withLock { $0.append(request) }
        return AIResponse(requestID: request.id, content: "cloud")
    }
}
