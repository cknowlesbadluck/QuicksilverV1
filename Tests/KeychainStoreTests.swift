import XCTest
@testable import Core

/// Covers the update-in-place semantics of `KeychainStore.set`.
final class KeychainStoreTests: XCTestCase {
    private var key = ""

    override func setUp() {
        super.setUp()
        key = "test.keychain.\(UUID().uuidString)"
    }

    override func tearDown() {
        KeychainStore.delete(forKey: key)
        super.tearDown()
    }

    private func requireKeychain() throws {
        guard KeychainStore.set("probe", forKey: key) else {
            throw XCTSkip("Keychain is not available in this test environment")
        }
    }

    func testSetAddsThenUpdatesInPlace() throws {
        try requireKeychain()
        XCTAssertEqual(KeychainStore.string(forKey: key), "probe")

        XCTAssertTrue(KeychainStore.set("second", forKey: key))
        XCTAssertEqual(KeychainStore.string(forKey: key), "second")

        XCTAssertTrue(KeychainStore.set("third", forKey: key))
        XCTAssertEqual(KeychainStore.string(forKey: key), "third")
    }

    func testSettingNilDeletesAndIsIdempotent() throws {
        try requireKeychain()
        XCTAssertTrue(KeychainStore.set(nil as Data?, forKey: key))
        XCTAssertNil(KeychainStore.data(forKey: key))
        // Deleting a missing item is still a success.
        XCTAssertTrue(KeychainStore.set(nil as Data?, forKey: key))
    }

    func testDeleteReportsSuccessIncludingMissingItem() throws {
        try requireKeychain()
        XCTAssertTrue(KeychainStore.delete(forKey: key))
        XCTAssertNil(KeychainStore.data(forKey: key))
        XCTAssertTrue(KeychainStore.delete(forKey: key), "missing item counts as removed")
    }
}

/// Keychain read typing: "locked" is not "missing".
final class KeychainCredentialStateTests: XCTestCase {
    func testStatesMapFromReadResults() {
        XCTAssertEqual(KeychainStore.credentialState(from: .success(Data("k".utf8))), .present)
        XCTAssertEqual(KeychainStore.credentialState(from: .success(nil)), .missing)
        XCTAssertEqual(KeychainStore.credentialState(from: .success(Data())), .missing)
        XCTAssertEqual(KeychainStore.credentialState(from: .failure(.locked)), .locked)
        XCTAssertEqual(KeychainStore.credentialState(from: .failure(.failed(-1))), .unreadable(-1))
    }

    func testInterpretMapsInteractionNotAllowedToLocked() {
        XCTAssertThrowsError(try KeychainStore.interpret(status: errSecInteractionNotAllowed, item: nil)) { error in
            XCTAssertEqual(error as? KeychainStore.ReadError, .locked)
        }
        XCTAssertNil(try KeychainStore.interpret(status: errSecItemNotFound, item: nil))
    }

    func testMissingKeyReadsAsMissing() {
        XCTAssertEqual(KeychainStore.credentialState(forKey: "test.absent.\(UUID().uuidString)"), .missing)
    }
}
