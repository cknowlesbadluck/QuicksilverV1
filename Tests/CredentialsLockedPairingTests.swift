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

/// Codex P1: providers built while the Keychain was locked are rebuilt after first unlock.
final class ProviderRehydrationTests: XCTestCase {
    func testRehydratesWhenUnboundAndACredentialIsNowReadable() {
        XCTAssertTrue(AIService.shouldRehydrate(primaryBound: false, states: [.missing, .missing, .present, .missing]))
    }

    func testDoesNotRehydrateWhenAlreadyBound() {
        XCTAssertFalse(AIService.shouldRehydrate(primaryBound: true, states: [.present, .present, .present, .present]))
    }

    func testDoesNotRehydrateWhileStillLockedOrEmpty() {
        XCTAssertFalse(AIService.shouldRehydrate(primaryBound: false, states: [.locked, .locked, .locked, .missing]))
        XCTAssertFalse(AIService.shouldRehydrate(primaryBound: false, states: [.missing, .missing, .missing, .missing]))
        XCTAssertFalse(AIService.shouldRehydrate(primaryBound: false, states: [.unreadable(-1), .missing]))
    }

    func testGatewayLockedRequiresBothHalves() {
        XCTAssertTrue(AIService.isGatewayLocked([.present, .locked]))
        XCTAssertFalse(AIService.isGatewayLocked([.locked, .missing]))
        XCTAssertFalse(AIService.isGatewayLocked([.present, .present]))
    }
}
