import XCTest
@testable import Quicksilver
import Core
import Memory
import ServicesAI
import Nexus

@MainActor
final class DependencyContainerTests: XCTestCase {
    func testSpotlightReadinessRecoversAfterInitialMemoryLoadFailure() async throws {
        let suiteName = "DependencyContainerRetryTests.\\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = FailOnceMemoryStore()
        let logger = LoggerService(subsystem: "com.quicksilver.tests")
        let eventBus = EventBus()
        let nexus = NexusCoordinator(
            networkMonitor: StubNetworkMonitor(),
            batteryMonitor: StubBatteryMonitor(),
            storageMonitor: StubStorageMonitor(),
            deviceMonitor: StubDeviceMonitor(),
            logger: logger,
            eventBus: eventBus
        )
        let container = DependencyContainer(memoryStore: store, nexus: nexus, defaults: defaults)
        await container.noteSpotlight.setEnabled(true)

        for _ in 0..<50 {
            if await store.loadAttempts() > 0 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let initialLoadAttempts = await store.loadAttempts()
        XCTAssertEqual(initialLoadAttempts, 1)
        XCTAssertFalse(container.noteSpotlight.isMemoryReady)

        await container.brain.remember("Spotlight retry after transient store failure")
        for _ in 0..<100 where !container.noteSpotlight.isMemoryReady {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertTrue(container.noteSpotlight.isMemoryReady, "a later successful load must release the Spotlight readiness gate")
        let stored = try await store.loadAll()
        XCTAssertTrue(stored.contains(where: { $0.value == "Spotlight retry after transient store failure" }))
    }

    func testInjectedStoreAndProviderDriveBrainWithoutUsingDeviceBackends() async throws {
        let suiteName = "DependencyContainerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let memoryStore = InMemoryMemoryStore()
        let provider = StubAIProvider()
        let logger = LoggerService(subsystem: "com.quicksilver.tests")
        let eventBus = EventBus()
        let nexus = NexusCoordinator(
            networkMonitor: StubNetworkMonitor(),
            batteryMonitor: StubBatteryMonitor(),
            storageMonitor: StubStorageMonitor(),
            deviceMonitor: StubDeviceMonitor(),
            logger: logger,
            eventBus: eventBus
        )

        let container = DependencyContainer(
            memoryStore: memoryStore,
            aiProvider: provider,
            nexus: nexus,
            defaults: defaults
        )
        container.featureFlags.set("aiServiceEnabled", enabled: true)

        let reply = try await container.brain.ask("Give me one crisp recommendation.")
        XCTAssertEqual(reply, StubAIProvider.reply)

        await container.brain.remember("Keep the injection seam small.")
        let stored = try await memoryStore.loadAll()
        XCTAssertTrue(stored.contains(where: { (item: MemoryItem) in
            item.value == "Keep the injection seam small."
        }))
    }
}

private actor FailOnceMemoryStore: MemoryStore {
    private var items: [MemoryItem] = []
    private var loads = 0

    func loadAttempts() -> Int { loads }

    func loadAll() async throws -> [MemoryItem] {
        loads += 1
        if loads == 1 { throw Failure.transientRead }
        return items
    }

    func save(_ item: MemoryItem) async throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    func deleteAll(in category: MemoryItem.Category) async throws {
        items.removeAll { $0.category == category }
    }

    private enum Failure: Error { case transientRead }
}

private struct StubAIProvider: AIProvider {
    static let reply = "Use one narrow injection seam and verify it end to end."

    let id = "stub"
    let displayName = "Stub"
    let isAvailable = true

    func complete(_ request: AIRequest) async throws -> AIResponse {
        AIResponse(requestID: request.id, content: Self.reply)
    }
}

private final class StubNetworkMonitor: NetworkMonitoring {
    let diagnosticID = "network-test"
    var isConnected = true
    var isExpensive = false
    var isConstrained = false
    var onChange: ((Bool, Bool, Bool) -> Void)?

    func start() {}
    func stop() {}
}

private final class StubBatteryMonitor: BatteryMonitoring {
    let diagnosticID = "battery-test"
    var level = 1.0
    var stateDescription = "full"
    var onChange: ((Double, String) -> Void)?

    func start() {}
    func stop() {}
}

private final class StubStorageMonitor: StorageMonitoring {
    let diagnosticID = "storage-test"
    var availableGB = 100.0
    var totalGB = 128.0
    var onChange: ((Double, Double) -> Void)?

    func start() {}
    func stop() {}
}

private final class StubDeviceMonitor: DeviceMetricsMonitoring {
    let diagnosticID = "device-test"
    var thermalStateDescription = "nominal"
    var isLowPowerMode = false
    var onChange: ((String, Bool) -> Void)?

    func start() {}
    func stop() {}
}
