import XCTest
@testable import Core

final class AppErrorTests: XCTestCase {

    func testConfigurationMissingDescription() {
        let error = AppError.configurationMissing("API_KEY")
        XCTAssertEqual(error.errorDescription, "Missing configuration: API_KEY")
    }

    func testPersonaUnavailableDescription() {
        let error = AppError.personaUnavailable("Forge")
        XCTAssertEqual(error.errorDescription, "Persona unavailable: Forge")
    }

    func testNexusNotReadyDescription() {
        let error = AppError.nexusNotReady
        XCTAssertEqual(error.errorDescription, "Nexus subsystem is not ready")
    }

    func testNetworkUnavailableDescription() {
        let error = AppError.networkUnavailable
        XCTAssertEqual(error.errorDescription, "Network is currently unavailable")
    }

    func testUnsupportedFeatureDescription() {
        let error = AppError.unsupportedFeature("Holograms")
        XCTAssertEqual(error.errorDescription, "Feature not yet supported: Holograms")
    }

    func testApiKeyMissingDescription() {
        let error = AppError.apiKeyMissing
        XCTAssertEqual(error.errorDescription, "AI API key is not configured")
    }

    func testAiRequestFailedDescription() {
        let error = AppError.aiRequestFailed("Timeout")
        XCTAssertEqual(error.errorDescription, "AI request failed. Please try again.")
    }

    func testUnknownDescription() {
        let error = AppError.unknown("Something went completely wrong")
        XCTAssertEqual(error.errorDescription, "Something went completely wrong")
    }
}
