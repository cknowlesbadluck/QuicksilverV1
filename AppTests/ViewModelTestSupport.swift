import XCTest
@testable import Quicksilver
import Core
import Memory
import ServicesAI
import Nexus

/// Shared simulator harness for Codex and Ask view-model tests.
@MainActor
enum ViewModelTestSupport {
    static func makeContainer(
        provider: AIProvider?,
        testCase: XCTestCase
    ) throws -> DependencyContainer {
        let suiteName = "ViewModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        testCase.addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }

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
        return DependencyContainer(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: provider,
            nexus: nexus,
            defaults: defaults
        )
    }

    /// Clears provider keys for the test and restores whatever was there.
    static func isolateProviderKeychain(testCase: XCTestCase) {
        let grokKey = AIService.grokAPIKeyKeychainAccount
        let geminiKey = AIService.geminiAPIKeyKeychainAccount
        let gatewayURL = AIService.gatewayBaseURLKeychainAccount
        let gatewayToken = GatewayAIProvider.deviceTokenKeychainAccount
        let previousGrok = KeychainStore.string(forKey: grokKey)
        let previousGemini = KeychainStore.string(forKey: geminiKey)
        let previousGatewayURL = KeychainStore.string(forKey: gatewayURL)
        let previousGatewayToken = KeychainStore.string(forKey: gatewayToken)
        KeychainStore.delete(forKey: grokKey)
        KeychainStore.delete(forKey: geminiKey)
        KeychainStore.delete(forKey: gatewayURL)
        KeychainStore.delete(forKey: gatewayToken)
        testCase.addTeardownBlock {
            restore(previousGrok, forKey: grokKey)
            restore(previousGemini, forKey: geminiKey)
            restore(previousGatewayURL, forKey: gatewayURL)
            restore(previousGatewayToken, forKey: gatewayToken)
        }
    }

    private static func restore(_ value: String?, forKey key: String) {
        if let value {
            _ = KeychainStore.set(value, forKey: key)
        } else {
            KeychainStore.delete(forKey: key)
        }
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
