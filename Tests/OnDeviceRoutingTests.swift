import Synchronization
import XCTest
@testable import Core
@testable import ServicesAI

/// M3.5-T3: on-device first, cloud fallback, typed reasons, compact prompt.
@MainActor
final class OnDeviceRoutingTests: XCTestCase {
    private func makeService(cloud: AIProvider?, model: ScriptedOnDeviceModel?) -> AIService {
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "OnDeviceRoutingTests.\(UUID().uuidString)") ?? .standard)
        flags.set("aiServiceEnabled", enabled: true)
        let service = AIService(primary: cloud, secondary: nil, eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        service.onDeviceProvider = model.map { OnDeviceAIProvider(model: $0) }
        service.retrySleep = { _ in }
        return service
    }

    private func request() -> AIRequest {
        let history = (1...10).map { Message(role: $0.isMultiple(of: 2) ? .assistant : .user, content: "turn-\($0)") }
        return AIRequest(
            prompt: "plan the shelf",
            systemPrompt: "FULL cloud prompt",
            history: history,
            metadata: [AIService.onDeviceInstructionsKey: "COMPACT prompt"]
        )
    }

    func testAvailableOnDeviceAnswersFirstWithCompactPrompt() async throws {
        let cloud = CountingCloud()
        let model = ScriptedOnDeviceModel(availability: .available, outcome: .reply("local"))
        let service = makeService(cloud: cloud, model: model)

        XCTAssertEqual(service.activeRouteName, OnDeviceAIProvider.routeName)
        let response = try await service.complete(request())
        XCTAssertEqual(response.content, "local")
        XCTAssertEqual(cloud.calls, 0, "Nothing leaves the device when on-device answers")
        let call = try XCTUnwrap(model.calls.first)
        XCTAssertEqual(call.instructions, "COMPACT prompt")
        XCTAssertFalse(call.prompt.contains("turn-6"), "Only the newest turns reach the small model")
        XCTAssertTrue(call.prompt.contains("turn-7"))
    }

    func testUnavailableOnDeviceFallsBackToCloudWithReason() async throws {
        let cloud = CountingCloud()
        let service = makeService(
            cloud: cloud,
            model: ScriptedOnDeviceModel(availability: .appleIntelligenceNotEnabled, outcome: .reply("x"))
        )
        XCTAssertEqual(service.onDeviceAvailability, .appleIntelligenceNotEnabled)
        XCTAssertFalse(service.onDeviceAvailability.userFacingReason.isEmpty)
        XCTAssertEqual(service.activeRouteName, "Cloud")

        let response = try await service.complete(request())
        XCTAssertEqual(response.content, "cloud")
        XCTAssertEqual(cloud.calls, 1)
    }

    func testOnDeviceFailureFallsBackToCloud() async throws {
        let cloud = CountingCloud()
        let service = makeService(
            cloud: cloud,
            model: ScriptedOnDeviceModel(availability: .available, outcome: .fail(.generationFailed("mid-stream")))
        )
        let response = try await service.complete(request())
        XCTAssertEqual(response.content, "cloud")
        XCTAssertEqual(cloud.calls, 1)
    }

    func testOnDeviceFailureWithoutCloudSurfacesError() async {
        let service = makeService(
            cloud: nil,
            model: ScriptedOnDeviceModel(availability: .available, outcome: .fail(.contextWindowExceeded))
        )
        do {
            _ = try await service.complete(request())
            XCTFail("Expected failure")
        } catch let error as AppError {
            guard case .aiRequestFailed = error else { return XCTFail("Unexpected \(error)") }
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    func testKeylessButOnDeviceReadyIsBound() throws {
        let service = makeService(cloud: nil, model: ScriptedOnDeviceModel(availability: .available, outcome: .reply("x")))
        XCTAssertTrue(service.isBound)
        XCTAssertNoThrow(try service.ensureReadyForNetworkRequest())
    }

    func testNoOnDeviceAndNoCloudStaysUnbound() {
        let service = makeService(cloud: nil, model: nil)
        XCTAssertFalse(service.isBound)
        XCTAssertEqual(service.onDeviceAvailability, .unsupportedOS)
        XCTAssertThrowsError(try service.ensureReadyForNetworkRequest())
    }

    func testCompactRequestDropsCloudContext() {
        let compact = AIService.onDeviceRequest(from: request())
        XCTAssertEqual(compact.systemPrompt, "COMPACT prompt")
        XCTAssertEqual(compact.history.count, AIService.onDeviceHistoryTurns)
        XCTAssertTrue(compact.context.isEmpty)
    }
}

private final class CountingCloud: AIProvider {
    let id = "cloud"
    let displayName = "Cloud"
    let isAvailable = true
    private let count = Mutex(0)
    var calls: Int { count.withLock { $0 } }
    func complete(_ request: AIRequest) async throws -> AIResponse {
        count.withLock { $0 += 1 }
        return AIResponse(requestID: request.id, content: "cloud")
    }
}

final class ScriptedOnDeviceModel: OnDeviceLanguageModel {
    enum Outcome: Sendable { case reply(String), fail(OnDeviceModelError) }
    struct Call: Sendable { let instructions: String?; let prompt: String }
    let availability: OnDeviceModelAvailability
    let outcome: Outcome
    private let recorded = Mutex<[Call]>([])
    var calls: [Call] { recorded.withLock { $0 } }

    init(availability: OnDeviceModelAvailability, outcome: Outcome) {
        self.availability = availability
        self.outcome = outcome
    }

    func respond(instructions: String?, prompt: String) async throws -> String {
        recorded.withLock { $0.append(Call(instructions: instructions, prompt: prompt)) }
        switch outcome {
        case .reply(let text): return text
        case .fail(let error): throw error
        }
    }
}
