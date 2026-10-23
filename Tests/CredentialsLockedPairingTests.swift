import XCTest
@testable import Core
@testable import ServicesAI

/// The gateway URL + token are a single binding for "locked" vs "unbound".
final class CredentialsLockedPairingTests: XCTestCase {
    func testLoneLockedGatewayHalfIsNotLocked() {
        XCTAssertFalse(AIService.isLocked(gatewayHalves: [.locked, .missing], standaloneKeys: [.missing, .missing]))
        XCTAssertFalse(AIService.isLocked(gatewayHalves: [.missing, .locked], standaloneKeys: [.missing, .missing]))
    }

    func testCompleteGatewayBindingWithLockedHalfIsLocked() {
        XCTAssertTrue(AIService.isLocked(gatewayHalves: [.locked, .locked], standaloneKeys: [.missing, .missing]))
        XCTAssertTrue(AIService.isLocked(gatewayHalves: [.present, .locked], standaloneKeys: [.missing, .missing]))
    }

    func testStandaloneKeysCountIndividually() {
        XCTAssertTrue(AIService.isLocked(gatewayHalves: [.missing, .missing], standaloneKeys: [.locked, .missing]))
        XCTAssertFalse(AIService.isLocked(gatewayHalves: [.missing, .missing], standaloneKeys: [.missing, .unreadable(-1)]))
    }
}
