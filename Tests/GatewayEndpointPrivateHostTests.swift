import XCTest
@testable import Core
@testable import ServicesAI

/// GatewayEndpoint fails closed on private, link-local and loopback hosts over HTTPS.
final class GatewayEndpointPrivateHostTests: XCTestCase {
    func testRefusesPrivateLinkLocalAndLoopbackHTTPS() {
        let refused = [
            "https://10.0.0.5", "https://192.168.1.20:8443", "https://172.16.4.1", "https://172.31.255.1",
            "https://169.254.169.254", "https://127.0.0.1", "https://[::1]", "https://[fe80::1]",
            "https://[fd12:3456::1]", "https://[fc00::1]"
        ]
        for raw in refused {
            XCTAssertThrowsError(try GatewayEndpoint(raw: raw), raw) { error in
                XCTAssertEqual(error as? GatewayEndpointError, .privateHost, raw)
            }
        }
    }

    func testAllowsPublicHostsAndBoundaryAddresses() throws {
        for raw in ["https://mercury.example.workers.dev", "https://172.15.0.1", "https://172.32.0.1",
                    "https://8.8.8.8", "https://[2606:4700::1111]"] {
            XCTAssertNoThrow(try GatewayEndpoint(raw: raw), raw)
        }
    }

    func testPlainHTTPLocalhostDevExceptionUnchanged() throws {
        XCTAssertNoThrow(try GatewayEndpoint(raw: "http://127.0.0.1:8787"))
        XCTAssertThrowsError(try GatewayEndpoint(raw: "http://192.168.1.20"))
    }

    func testPolicyRefusesIPv6UniqueLocal() {
        XCTAssertEqual(MercuryEndpointPolicy().evaluate("https://[fd00::1]").refusal, .privateAddress)
    }
}
