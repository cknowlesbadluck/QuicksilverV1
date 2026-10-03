import XCTest
@testable import Core

final class MercuryEndpointPolicyTests: XCTestCase {
    private let policy = MercuryEndpointPolicy()

    func testPublicHTTPSIsAllowed() {
        let verdict = policy.evaluate("https://api.x.ai/v1/chat/completions")
        XCTAssertEqual(verdict, .allow)
    }

    func testEmptyAndCleartextAreRefused() {
        XCTAssertEqual(policy.evaluate("   "), .refuse(.empty))
        XCTAssertEqual(policy.evaluate("http://api.x.ai/v1"), .refuse(.notHTTPS))
        XCTAssertEqual(policy.evaluate("file:///tmp/secret"), .refuse(.notHTTPS))
    }

    func testUserinfoAndMissingHostAreRefused() {
        XCTAssertEqual(policy.evaluate("https://user:secret@api.x.ai/v1"), .refuse(.userinfo))
        XCTAssertEqual(policy.evaluate("https:///no-host"), .refuse(.missingHost))
    }

    func testLoopbackPrivateAndLinkLocalAreRefused() {
        XCTAssertEqual(policy.evaluate("https://localhost/mcp"), .refuse(.loopback))
        XCTAssertEqual(policy.evaluate("https://127.0.0.1/mcp"), .refuse(.loopback))
        XCTAssertEqual(policy.evaluate("https://10.1.2.3/mcp"), .refuse(.privateAddress))
        XCTAssertEqual(policy.evaluate("https://192.168.1.9/mcp"), .refuse(.privateAddress))
        XCTAssertEqual(policy.evaluate("https://172.16.0.4/mcp"), .refuse(.privateAddress))
        XCTAssertEqual(policy.evaluate("https://169.254.1.1/latest"), .refuse(.linkLocal))
        XCTAssertEqual(policy.evaluate("https://printer.local/mcp"), .refuse(.loopback))
    }
}
