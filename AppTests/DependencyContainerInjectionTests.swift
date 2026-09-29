import XCTest
import Core
import Memory
import ServicesAI
import Nexus
@testable import Quicksilver

@MainActor
final class DependencyContainerInjectionTests: XCTestCase {
    func testInjectedMemoryStoreAndProvider() async throws {
        let suite = "qs.m2t3.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = InMemoryMemoryStore()
        let provider = MockAIProvider()
        let logger = LoggerService(subsystem: "com.quicksilver.tests")
        let eventBus = EventBus()
        let nexus = NexusCoordinator(logger: logger, eventBus: eventBus)

        let container = DependencyContainer(
            memoryStore: store,
            aiProvider: provider,
            nexus: nexus,
            defaults: defaults
        )

        XCTAssertEqual(container.aiService.currentProviderID, provider.id)
        XCTAssertEqual(container.aiService.currentProviderName, provider.displayName)
        XCTAssertFalse(container.nexus.isActive)

        await container.memoryManager.set(
            key: "m2t3.note",
            value: "kept in the injected store",
            category: .preference
        )

        let stored = try await store.loadAll()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.key, "m2t3.note")
        XCTAssertEqual(container.memoryManager.items.count, 1)

        container.featureFlags.set("aiServiceEnabled", enabled: true)
        let saved = defaults.dictionary(forKey: "quicksilver.featureFlags") as? [String: Bool]
        XCTAssertEqual(saved?["aiServiceEnabled"], true)
    }
}
