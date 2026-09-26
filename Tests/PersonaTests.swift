import XCTest
@testable import Personas

/// Configuration surface tests.
/// The legacy Persona protocol has been removed; PersonaConfiguration is the sole source of truth.
final class PersonaTests: XCTestCase {
    func testQuicksilverConfiguration() {
        let config = PersonaConfiguration.quicksilver
        XCTAssertEqual(config.id, "quicksilver")
        XCTAssertFalse(config.displayName.isEmpty)
        XCTAssertFalse(config.systemPrompt.isEmpty)
        XCTAssertEqual(config.accentColorName, "quicksilverCyan")
        XCTAssertEqual(config.preferredTemperature, 0.7, accuracy: 0.0001)
        XCTAssertEqual(config.maxTokensHint, 1024)
    }

    func testForgeConfiguration() {
        let config = PersonaConfiguration.forge
        XCTAssertEqual(config.id, "forge")
        XCTAssertEqual(config.displayName, "Forge")
        XCTAssertEqual(config.preferredTemperature, 0.45, accuracy: 0.0001)
        XCTAssertEqual(config.maxTokensHint, 1536)
    }

    func testEternalConfiguration() {
        let config = PersonaConfiguration.eternal
        XCTAssertEqual(config.id, "eternal")
        XCTAssertEqual(config.displayName, "Eternal")
        XCTAssertEqual(config.preferredTemperature, 0.35, accuracy: 0.0001)
        XCTAssertEqual(config.maxTokensHint, 512)
    }

    func testAllConfigurationsAreDistinct() {
        let ids = PersonaConfiguration.all.map(\.id)
        XCTAssertEqual(Set(ids).count, 3, "Persona configuration IDs must be unique")
    }

    func testAllContainsTheThreeCanonicalConfigs() {
        let ids = Set(PersonaConfiguration.all.map(\.id))
        XCTAssertTrue(ids.contains("quicksilver"))
        XCTAssertTrue(ids.contains("forge"))
        XCTAssertTrue(ids.contains("eternal"))
    }

    func testMaxTokensHintOrdering() {
        XCTAssertGreaterThan(
            PersonaConfiguration.forge.maxTokensHint,
            PersonaConfiguration.quicksilver.maxTokensHint
        )
        XCTAssertGreaterThan(
            PersonaConfiguration.quicksilver.maxTokensHint,
            PersonaConfiguration.eternal.maxTokensHint
        )
    }
}
