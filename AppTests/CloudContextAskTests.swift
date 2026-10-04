import XCTest
@testable import Quicksilver
import Core
import Memory
import ServicesAI
import Nexus
import Personas

@MainActor
final class CloudContextAskTests: XCTestCase {
    /// M3-T11: trainsOnPrompts forces minimal — no memory/device context, ≤2 pairs.
    func testAskCloudContextMinimalOmitsMemoryAndDevice() async throws {
        let recorder = CloudAskRecorder(reply: "ok", trainsOnPrompts: true)
        let harness = try makeHarness(provider: recorder)
        harness.container.featureFlags.set("aiServiceEnabled", enabled: true)
        await harness.container.brain.remember("shareable preference tea")

        _ = try await harness.container.brain.ask("first")
        _ = try await harness.container.brain.ask("second")
        _ = try await harness.container.brain.ask("third")

        let last = try XCTUnwrap(recorder.requests.last)
        XCTAssertLessThanOrEqual(last.history.count, 4)
        XCTAssertFalse((last.systemPrompt ?? "").contains("shareable preference"))
        XCTAssertFalse((last.systemPrompt ?? "").contains("Device context"))
        XCTAssertFalse(last.context.contains { $0.kind == .memory })
        XCTAssertFalse(last.context.contains { $0.kind == .device })
        XCTAssertEqual(GatewayRequest.makeChatBody(last).context, last.context)
    }

    /// M3-T11: standard level snapshots memory + allowlisted device in context blocks.
    func testAskCloudContextStandardSnapshotsPayload() async throws {
        let recorder = CloudAskRecorder(reply: "ok", trainsOnPrompts: false)
        let harness = try makeHarness(provider: recorder)
        harness.container.featureFlags.set("aiServiceEnabled", enabled: true)
        harness.container.nexus.noteBatteryCondition(level: 0.2)
        await harness.container.brain.remember("plan the day with terse answers")

        _ = try await harness.container.brain.ask("plan the day")

        let last = try XCTUnwrap(recorder.requests.last)
        XCTAssertFalse((last.systemPrompt ?? "").contains("Device context (private)"))
        XCTAssertTrue((last.systemPrompt ?? "").contains("terse answers"), "direct providers get cloud-safe appendix")
        let memories = last.context.filter { $0.kind == .memory }
        XCTAssertEqual(memories.count, 1)
        XCTAssertEqual(memories[0].text, "plan the day with terse answers")
        XCTAssertTrue(last.context.contains { $0.kind == .device && $0.text == "battery low" })
        let body = GatewayRequest.makeChatBody(last)
        XCTAssertTrue(body.context.contains { $0.kind == .memory })
        XCTAssertTrue(body.context.contains { $0.kind == .device && $0.text == "battery low" })
    }

    private func makeHarness(provider: AIProvider) throws -> CloudAskHarness {
        let suiteName = "CloudContextAskTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }

        let logger = LoggerService(subsystem: "com.quicksilver.tests")
        let eventBus = EventBus()
        let store = InMemoryMemoryStore()
        let nexus = NexusCoordinator(
            networkMonitor: CloudAskNetworkMonitor(),
            batteryMonitor: CloudAskBatteryMonitor(),
            storageMonitor: CloudAskStorageMonitor(),
            deviceMonitor: CloudAskDeviceMonitor(),
            logger: logger,
            eventBus: eventBus
        )
        let container = DependencyContainer(
            memoryStore: store,
            aiProvider: provider,
            nexus: nexus,
            defaults: defaults
        )
        return CloudAskHarness(container: container, store: store)
    }
}

private struct CloudAskHarness {
    let container: DependencyContainer
    let store: InMemoryMemoryStore
}

private final class CloudAskRecorder: AIProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [AIRequest] = []
    var requests: [AIRequest] { lock.withLock { _requests } }

    let reply: String
    let trainsOnPrompts: Bool
    let id = "cloud-ask-recorder"
    let displayName = "CloudAskRecorder"
    let isAvailable = true

    init(reply: String, trainsOnPrompts: Bool) {
        self.reply = reply
        self.trainsOnPrompts = trainsOnPrompts
    }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        lock.withLock { _requests.append(request) }
        return AIResponse(requestID: request.id, content: reply)
    }
}

private final class CloudAskNetworkMonitor: NetworkMonitoring {
    let diagnosticID = "network-test"
    var isConnected = true
    var isExpensive = false
    var isConstrained = false
    var onChange: ((Bool, Bool, Bool) -> Void)?
    func start() {}
    func stop() {}
}

private final class CloudAskBatteryMonitor: BatteryMonitoring {
    let diagnosticID = "battery-test"
    var level = 1.0
    var stateDescription = "full"
    var onChange: ((Double, String) -> Void)?
    func start() {}
    func stop() {}
}

private final class CloudAskStorageMonitor: StorageMonitoring {
    let diagnosticID = "storage-test"
    var availableGB = 100.0
    var totalGB = 128.0
    var onChange: ((Double, Double) -> Void)?
    func start() {}
    func stop() {}
}

private final class CloudAskDeviceMonitor: DeviceMetricsMonitoring {
    let diagnosticID = "device-test"
    var thermalStateDescription = "nominal"
    var isLowPowerMode = false
    var onChange: ((String, Bool) -> Void)?
    func start() {}
    func stop() {}
}
