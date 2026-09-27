import XCTest
@testable import Core
@testable import Personas

@MainActor
final class PersonaManagerTests: XCTestCase {

    func testInitialPersonaIsQuicksilver() {
        let bus = EventBus()
        let logger = LoggerService()
        let manager = PersonaManager(eventBus: bus, logger: logger)
        XCTAssertEqual(manager.activeConfiguration.id, "quicksilver")
    }

    func testSwitchToForge() async throws {
        let bus = EventBus()
        let logger = LoggerService()
        let manager = PersonaManager(eventBus: bus, logger: logger)
        try await manager.switchTo(id: "forge")
        XCTAssertEqual(manager.activeConfiguration.id, "forge")
        XCTAssertEqual(manager.lastSwitchReason, "explicit override")
    }

    func testSwitchToUnknownThrows() async {
        let bus = EventBus()
        let logger = LoggerService()
        let manager = PersonaManager(eventBus: bus, logger: logger)
        do {
            try await manager.switchTo(id: "nonexistent")
            XCTFail("Expected error")
        } catch { }
    }

    func testSwitchToSameIdIsNoOp() async throws {
        let bus = EventBus()
        let logger = LoggerService()
        let manager = PersonaManager(eventBus: bus, logger: logger)
        try await manager.switchTo(id: "quicksilver")
        XCTAssertNil(manager.lastSwitchReason)
        XCTAssertEqual(manager.activeConfiguration.id, "quicksilver")
    }
}
