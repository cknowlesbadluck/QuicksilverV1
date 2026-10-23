import XCTest
@testable import ServicesAI

/// `/v1/config` (Bearer token) and `/v1/health` use an ephemeral session that refuses redirects,
/// so the device token can't follow a 3xx to another host and nothing is written to the disk cache.
final class GatewaySecureSessionTests: XCTestCase {
    func testRejectorRefusesEveryRedirect() throws {
        let origin = try XCTUnwrap(URL(string: "https://gateway.example/v1/config"))
        let target = try XCTUnwrap(URL(string: "https://evil.example/collect"))
        let task = URLSession(configuration: .ephemeral).dataTask(with: origin) // never resumed
        let response = try XCTUnwrap(HTTPURLResponse(
            url: origin, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": target.absoluteString]
        ))
        var redirected = URLRequest(url: target)
        redirected.setValue("Bearer device-token", forHTTPHeaderField: "Authorization")

        var followed: URLRequest? = redirected
        GatewayRedirectRejector.shared.urlSession(
            URLSession.shared, task: task, willPerformHTTPRedirection: response, newRequest: redirected
        ) { followed = $0 }

        XCTAssertNil(followed, "the redirect (and its Authorization header) is never followed")
    }

    func testSharedSecureSessionUsesRejectorAndNoDiskCache() {
        let session = GatewayStreamTransport.secureSession
        XCTAssertTrue(session.delegate is GatewayRedirectRejector)
        XCTAssertEqual(session.configuration.urlCache?.diskCapacity ?? 0, 0, "ephemeral: no disk cache")
    }

    func testInjectedConfigurationKeepsTheRejector() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 7
        let session = GatewayStreamTransport.makeSecureSession(configuration: config)
        XCTAssertTrue(session.delegate is GatewayRedirectRejector)
        XCTAssertEqual(session.configuration.timeoutIntervalForRequest, 7)
    }
}
