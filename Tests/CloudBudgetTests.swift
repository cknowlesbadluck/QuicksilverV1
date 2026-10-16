import Synchronization
import XCTest
@testable import Core
@testable import ServicesAI

/// Free-budget awareness: header parsing, recording from a fake gateway, and routing near the limit.
final class CloudBudgetTests: XCTestCase {
    private let noon = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!

    func testParsesCountsCaseInsensitively() {
        let budget = CloudBudget.parse(["X-Mercury-Budget-Remaining": "42", "x-mercury-budget-limit": " 300 "], now: noon)
        XCTAssertEqual(budget, CloudBudget(remaining: 42, limit: 300, day: "2026-10-15"))
        XCTAssertEqual(budget?.label, "42 of 300 left today")
        XCTAssertEqual(budget?.isNearLimit, false)
    }

    func testRejectsMissingOrMalformedHeaders() {
        XCTAssertNil(CloudBudget.parse([:]))
        XCTAssertNil(CloudBudget.parse(["x-mercury-budget-remaining": "5"]))
        XCTAssertNil(CloudBudget.parse(["x-mercury-budget-remaining": "-1", "x-mercury-budget-limit": "10"]))
        XCTAssertNil(CloudBudget.parse(["x-mercury-budget-remaining": "abc", "x-mercury-budget-limit": "10"]))
        XCTAssertNil(CloudBudget.parse(["x-mercury-budget-remaining": "0", "x-mercury-budget-limit": "0"]))
    }

    func testNearLimitAndExhaustedThresholds() {
        XCTAssertTrue(CloudBudget(remaining: 30, limit: 300, day: "d").isNearLimit)
        XCTAssertFalse(CloudBudget(remaining: 31, limit: 300, day: "d").isNearLimit)
        XCTAssertTrue(CloudBudget(remaining: 1, limit: 5, day: "d").isNearLimit, "at least one request")
        XCTAssertTrue(CloudBudget(remaining: 0, limit: 5, day: "d").isExhausted)
        XCTAssertEqual(CloudBudget(remaining: 9, limit: 5, day: "d").remaining, 5, "clamped to limit")
    }

    func testMonitorIgnoresYesterdaysReading() {
        let monitor = CloudBudgetMonitor()
        monitor.record(CloudBudget(remaining: 0, limit: 10, day: "2026-10-14"))
        XCTAssertNil(monitor.current(now: noon), "gateway resets at UTC midnight")
        monitor.record(nil)
        XCTAssertNil(monitor.current(now: noon))
    }

    func testRecordingTransportStoresBudgetFromFakeGateway() async throws {
        let monitor = CloudBudgetMonitor()
        let fake = GatewayStreamTransport { _ in
            GatewayOpenedStream(
                statusCode: 200,
                lines: AsyncThrowingStream { $0.finish() },
                budget: CloudBudget(remaining: 7, limit: 100, day: CloudBudget.utcDay(Date()))
            )
        }
        let request = URLRequest(url: URL(string: "https://mercury.example.workers.dev/v1/chat")!)
        _ = try await fake.recordingBudget(into: monitor).open(request)
        XCTAssertEqual(monitor.current()?.remaining, 7)
        XCTAssertEqual(monitor.current()?.isNearLimit, true)
    }
}

/// AIService routing with a fake gateway provider and the shared monitor.
@MainActor
final class CloudBudgetRoutingTests: XCTestCase {
    override func setUp() { CloudBudgetMonitor.shared.reset() }
    override func tearDown() { CloudBudgetMonitor.shared.reset() }

    private static let happy = "event: meta\ndata: {\"route\":\"cloud\",\"model\":\"fake\",\"trainsOnPrompts\":false}\n\n"
        + "event: delta\ndata: {\"text\":\"cloud\"}\n\nevent: done\ndata: {\"usage\":{\"promptTokens\":1,\"completionTokens\":1}}\n\n"

    private func makeService(model: ScriptedOnDeviceModel, opens: Mutex<Int>) throws -> AIService {
        let transport = GatewayStreamTransport { _ in
            opens.withLock { $0 += 1 }
            let lines = Self.happy.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            return GatewayOpenedStream(statusCode: 200, lines: AsyncThrowingStream { continuation in
                lines.forEach { continuation.yield($0) }
                continuation.finish()
            })
        }
        let gateway = try GatewayAIProvider(
            endpoint: try GatewayEndpoint(raw: "https://mercury.example.workers.dev"),
            deviceToken: "test-device",
            transport: transport
        )
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "CloudBudgetRoutingTests.\(UUID().uuidString)") ?? .standard)
        flags.set("aiServiceEnabled", enabled: true)
        let service = AIService(primary: gateway, secondary: nil, eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        service.onDeviceProvider = OnDeviceAIProvider(model: model)
        service.retrySleep = { _ in }
        return service
    }

    private func today(_ remaining: Int, of limit: Int) -> CloudBudget {
        CloudBudget(remaining: remaining, limit: limit, day: CloudBudget.utcDay(Date()))
    }

    func testExhaustedBudgetSkipsGatewayAfterOnDeviceFailure() async throws {
        let opens = Mutex(0)
        let service = try makeService(model: ScriptedOnDeviceModel(availability: .available, outcome: .fail(.generationFailed("x"))), opens: opens)
        CloudBudgetMonitor.shared.record(today(0, of: 100))
        do {
            _ = try await service.complete(AIRequest(prompt: "what is the capital of peru"))
            XCTFail("expected budgetExhausted")
        } catch {
            guard case AppError.budgetExhausted = error else { return XCTFail("got \(error)") }
        }
        XCTAssertEqual(opens.withLock { $0 }, 0, "no gateway round trip when the budget is spent")
    }

    func testNearLimitGivesOnDeviceASecondTryBeforeCloud() async throws {
        let opens = Mutex(0)
        let model = ScriptedOnDeviceModel(availability: .available, outcome: .fail(.generationFailed("x")))
        let service = try makeService(model: model, opens: opens)
        CloudBudgetMonitor.shared.record(today(5, of: 100))
        let response = try await service.complete(AIRequest(prompt: "what is the capital of peru"))
        XCTAssertEqual(response.content, "cloud")
        XCTAssertEqual(model.calls.count, 2, "one extra on-device attempt near the limit")
        XCTAssertEqual(opens.withLock { $0 }, 1)
    }

    func testHealthyBudgetKeepsSingleOnDeviceAttempt() async throws {
        let opens = Mutex(0)
        let model = ScriptedOnDeviceModel(availability: .available, outcome: .fail(.generationFailed("x")))
        let service = try makeService(model: model, opens: opens)
        CloudBudgetMonitor.shared.record(today(90, of: 100))
        _ = try await service.complete(AIRequest(prompt: "what is the capital of peru"))
        XCTAssertEqual(model.calls.count, 1)
        XCTAssertEqual(opens.withLock { $0 }, 1)
    }
}
