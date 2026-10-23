import Synchronization
import XCTest
@testable import Core
@testable import ServicesAI

/// Phase 9 hardening through the real gateway wire (fake transport, no network):
/// budget exhaustion and network loss before and after the first delta.
@MainActor
final class GatewayFailureMatrixTests: XCTestCase {
    private enum Script: Sendable {
        case lines([String])
        /// Yield these lines, then fail the byte stream with a lost connection.
        case linesThenLoss([String])
    }

    private func sse(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private nonisolated static let meta = "event: meta\ndata: {\"route\":\"cloud\",\"model\":\"fake\",\"trainsOnPrompts\":false}\n\n"

    private func makeService(_ scripts: [Script], onDevice: ScriptedOnDeviceModel? = nil) throws -> (AIService, Counter) {
        let counter = Counter()
        let queue = Mutex(scripts)
        let transport = GatewayStreamTransport { _ in
            counter.increment()
            let script = queue.withLock { $0.isEmpty ? Script.lines([]) : $0.removeFirst() }
            let stream = AsyncThrowingStream<String, Error> { continuation in
                switch script {
                case .lines(let lines):
                    lines.forEach { continuation.yield($0) }
                    continuation.finish()
                case .linesThenLoss(let lines):
                    lines.forEach { continuation.yield($0) }
                    continuation.finish(throwing: URLError(.networkConnectionLost))
                }
            }
            return GatewayOpenedStream(statusCode: 200, lines: stream)
        }
        let gateway = try GatewayAIProvider(
            endpoint: try GatewayEndpoint(raw: "https://mercury.example.workers.dev"),
            deviceToken: "test-device",
            transport: transport
        )
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "GatewayFailureMatrix.\(UUID().uuidString)") ?? .standard)
        flags.set("aiServiceEnabled", enabled: true)
        let service = AIService(primary: gateway, secondary: nil, eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        service.onDeviceProvider = onDevice.map { OnDeviceAIProvider(model: $0) }
        service.retrySleep = { _ in }
        return (service, counter)
    }

    private let question = AIRequest(prompt: "what is the boiling point of water")

    func testBudgetExhaustedEventIsTypedAndNotRetried() async throws {
        let (service, opens) = try makeService([.lines(sse("event: error\ndata: {\"code\":\"budget_exhausted\"}\n\n"))])
        do {
            _ = try await service.complete(question)
            XCTFail("expected budgetExhausted")
        } catch {
            guard case AppError.budgetExhausted = error else { return XCTFail("got \(error)") }
        }
        XCTAssertEqual(opens.value, 1, "budget exhaustion must not be retried")
        XCTAssertNil(service.lastAnswerProvenance)
    }

    func testBudgetExhaustedAfterOnDeviceFailureStaysTyped() async throws {
        let model = ScriptedOnDeviceModel(availability: .available, outcome: .fail(.generationFailed("x")))
        let (service, opens) = try makeService(
            [.lines(sse("event: error\ndata: {\"code\":\"budget_exhausted\"}\n\n"))],
            onDevice: model
        )
        do {
            _ = try await service.complete(question)
            XCTFail("expected budgetExhausted")
        } catch {
            guard case AppError.budgetExhausted = error else { return XCTFail("got \(error)") }
        }
        XCTAssertEqual(model.calls.count, 1)
        XCTAssertEqual(opens.value, 1)
    }

    func testNetworkLossAfterFirstDeltaKeepsPartialWithoutRetry() async throws {
        let (service, opens) = try makeService([.linesThenLoss(sse(Self.meta + "event: delta\ndata: {\"text\":\"Water boils\"}\n\n"))])
        let response = try await service.complete(question)
        XCTAssertEqual(response.finishReason, .incomplete)
        XCTAssertEqual(opens.value, 1, "never retry after a delta (no duplicate text)")
    }

    func testNetworkLossBeforeFirstDeltaRetriesOnceThenSucceeds() async throws {
        let happy = Self.meta + "event: delta\ndata: {\"text\":\"100 C\"}\n\nevent: done\ndata: {\"usage\":{\"promptTokens\":1,\"completionTokens\":1}}\n\n"
        let (service, opens) = try makeService([.linesThenLoss(sse(Self.meta)), .lines(sse(happy))])
        let response = try await service.complete(question)
        XCTAssertEqual(response.content, "100 C")
        XCTAssertEqual(opens.value, 2)
    }

    func testRepeatedNetworkLossSurfacesTypedNetworkError() async throws {
        let (service, opens) = try makeService([.linesThenLoss([]), .linesThenLoss([]), .linesThenLoss([])])
        do {
            _ = try await service.complete(question)
            XCTFail("expected a network error")
        } catch {
            XCTAssertTrue(error is AppError || error is URLError, "untyped: \(error)")
        }
        XCTAssertEqual(opens.value, 2, "at most one retry")
    }
}

private final class Counter: Sendable {
    private let count = Mutex(0)
    var value: Int { count.withLock { $0 } }
    func increment() { count.withLock { $0 += 1 } }
}
