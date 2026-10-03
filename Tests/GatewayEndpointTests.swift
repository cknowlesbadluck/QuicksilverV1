import XCTest
@testable import ServicesAI

/// Device-side bind contract for the Mercury gateway. Secrets never travel in the URL.
final class GatewayEndpointTests: XCTestCase {

    func testHTTPSOriginIsNormalized() throws {
        let endpoint = try GatewayEndpoint(raw: " https://mercury.example.workers.dev/ ")
        XCTAssertEqual(endpoint.url.absoluteString, "https://mercury.example.workers.dev")
    }

    func testHealthRequestHasNoTokenAndNoCache() throws {
        let endpoint = try GatewayEndpoint(raw: "https://mercury.example.workers.dev")
        let request = endpoint.healthRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/v1/health")
        XCTAssertNil(request.url?.query)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testAuthorizedRequestKeepsTokenOutOfTheURL() throws {
        let endpoint = try GatewayEndpoint(raw: "https://mercury.example.workers.dev")
        let token = "device-token-value"
        let request = try endpoint.authorizedRequest(path: "/v1/chat", deviceToken: token)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
        XCTAssertFalse(request.url?.absoluteString.contains(token) ?? true)
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.url?.path, "/v1/chat")
    }

    func testHTTPIsRejectedExceptLocalWrangler() throws {
        XCTAssertThrowsError(try GatewayEndpoint(raw: "http://mercury.example.workers.dev")) { error in
            XCTAssertEqual(error as? GatewayEndpointError, .notHTTPS)
        }
        let local = try GatewayEndpoint(raw: "http://127.0.0.1:8787")
        XCTAssertEqual(local.url.port, 8787)
    }

    func testQueryUserInfoAndFragmentAreRejected() {
        XCTAssertThrowsError(try GatewayEndpoint(raw: "https://user:secret@mercury.example.workers.dev")) { error in
            XCTAssertEqual(error as? GatewayEndpointError, .hasUserInfo)
        }
        XCTAssertThrowsError(try GatewayEndpoint(raw: "https://mercury.example.workers.dev?token=secret")) { error in
            XCTAssertEqual(error as? GatewayEndpointError, .hasQueryOrFragment)
        }
        XCTAssertThrowsError(try GatewayEndpoint(raw: "https://mercury.example.workers.dev#token")) { error in
            XCTAssertEqual(error as? GatewayEndpointError, .hasQueryOrFragment)
        }
    }

    func testTokenCannotBeSmuggledOnThePath() throws {
        let endpoint = try GatewayEndpoint(raw: "https://mercury.example.workers.dev")
        XCTAssertThrowsError(try endpoint.authorizedRequest(path: "/v1/chat?token=secret", deviceToken: "ok")) { error in
            XCTAssertEqual(error as? GatewayEndpointError, .tokenInURL)
        }
        XCTAssertThrowsError(try endpoint.authorizedRequest(path: "/v1/chat", deviceToken: "")) { error in
            XCTAssertEqual(error as? GatewayEndpointError, .tokenInURL)
        }
    }

    func testHealthDecodeAcceptsOnlyTheMercuryService() throws {
        let good = Data(#"{"ok":true,"service":"mercury-gateway"}"#.utf8)
        let health = try JSONDecoder().decode(GatewayHealth.self, from: good)
        XCTAssertTrue(health.isMercury)
        let other = Data(#"{"ok":true,"service":"something-else"}"#.utf8)
        XCTAssertFalse(try JSONDecoder().decode(GatewayHealth.self, from: other).isMercury)
    }

    func testConfigRequestIsAuthorizedGET() throws {
        let endpoint = try GatewayEndpoint(raw: "https://mercury.example.workers.dev")
        let token = "device-token-value"
        let request = try endpoint.authorizedRequest(path: "/v1/config", deviceToken: token, method: "GET")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertFalse(request.url?.absoluteString.contains(token) ?? true)
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.url?.path, "/v1/config")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }
}
