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
}
