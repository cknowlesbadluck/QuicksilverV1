import XCTest
@testable import Core
@testable import ServicesAI

final class RouteLogTests: XCTestCase {
    func testCapsAndReturnsNewestFirst() {
        let log = RouteLog()
        for index in 0..<(RouteLog.capacity + 5) {
            log.record(RouteRecord(date: Date(timeIntervalSince1970: TimeInterval(index)), route: .onDevice))
        }
        let recent = log.recent()
        XCTAssertEqual(recent.count, RouteLog.capacity)
        XCTAssertEqual(recent.first?.date, Date(timeIntervalSince1970: TimeInterval(RouteLog.capacity + 4)))
        XCTAssertEqual(log.recent(limit: 3).count, 3)
    }

    func testSummariesAreFixedTextWithoutContent() {
        let routes: [RouteRecord.Route] = [.onDevice, .cloudMinimal, .cloudStandard, .keptOnDevice, .budgetSpent, .failed]
        let summaries = routes.map { RouteRecord(route: $0, providerName: "Gemini").summary }
        XCTAssertEqual(Set(summaries).count, routes.count)
    }
}

/// AIService records one content-free route per turn.
@MainActor
final class RouteLogRoutingTests: XCTestCase {
    override func setUp() { RouteLog.shared.clear() }
    override func tearDown() { RouteLog.shared.clear() }

    private func service(cloud: AIProvider?, outcome: ScriptedOnDeviceModel.Outcome?) -> AIService {
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "RouteLog.\(UUID().uuidString)") ?? .standard)
        flags.set("aiServiceEnabled", enabled: true)
        let svc = AIService(primary: cloud, secondary: nil, eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        svc.onDeviceProvider = outcome.map { OnDeviceAIProvider(model: ScriptedOnDeviceModel(availability: .available, outcome: $0)) }
        svc.retrySleep = { _ in }
        return svc
    }

    func testOnDeviceTurnIsRecordedWithoutText() async throws {
        let svc = service(cloud: TrainingCloud(), outcome: .reply("secret reply text"))
        _ = try await svc.complete(AIRequest(prompt: "my secret prompt"))
        let record = try XCTUnwrap(RouteLog.shared.recent().first)
        XCTAssertEqual(record.route, .onDevice)
        XCTAssertFalse(record.summary.contains("secret"))
    }

    func testTrainingCloudFallbackIsRecordedAsMinimal() async throws {
        let svc = service(cloud: TrainingCloud(), outcome: .fail(.generationFailed("x")))
        _ = try await svc.complete(AIRequest(prompt: "what is the capital of peru"))
        XCTAssertEqual(RouteLog.shared.recent().first?.route, .cloudMinimal)
        XCTAssertEqual(RouteLog.shared.recent().first?.providerName, "Training Cloud")
    }

    func testPersonalTurnBlockedByGateIsRecorded() async {
        let svc = service(cloud: TrainingCloud(), outcome: .fail(.generationFailed("x")))
        _ = try? await svc.complete(AIRequest(prompt: "what should I tell my doctor about these symptoms"))
        XCTAssertEqual(RouteLog.shared.recent().first?.route, .keptOnDevice)
    }
}

private final class TrainingCloud: AIProvider {
    let id = "training-cloud"
    let displayName = "Training Cloud"
    let isAvailable = true
    var trainsOnPrompts: Bool { true }
    func complete(_ request: AIRequest) async throws -> AIResponse {
        AIResponse(requestID: request.id, content: "cloud")
    }
}
