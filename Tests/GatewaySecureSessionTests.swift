import XCTest
import Synchronization
@testable import ServicesAI

/// `/v1/config` (Bearer token) and `/v1/health` use an ephemeral session that refuses redirects,
/// so the device token can't follow a 3xx to another host and nothing is written to the disk cache.
final class GatewaySecureSessionTests: XCTestCase {
    override func tearDown() {
        RedirectStub.requests.withLock { $0 = [] }
        super.tearDown()
    }

    func testSecureSessionIsEphemeralAndRefusesRedirects() async throws {
        let session = GatewayStreamTransport.makeSecureSession(configuration: Self.stubbedEphemeral())
        var request = URLRequest(url: try XCTUnwrap(URL(string: "https://gateway.example/v1/config")))
        request.setValue("Bearer device-token", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 302, "the redirect is returned, not followed")
        let hosts = RedirectStub.requests.withLock { $0.compactMap(\.url?.host) }
        XCTAssertEqual(hosts, ["gateway.example"], "the token never reached the redirect target")
    }

    func testSharedSecureSessionUsesRejectorAndNoDiskCache() {
        let session = GatewayStreamTransport.secureSession
        XCTAssertTrue(session.delegate is GatewayRedirectRejector)
        XCTAssertEqual(session.configuration.urlCache?.diskCapacity ?? 0, 0, "ephemeral: no disk cache")
        XCTAssertNil(session.configuration.httpCookieStorage?.cookies?.first, "ephemeral: no persisted cookies")
    }

    private static func stubbedEphemeral() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RedirectStub.self]
        return config
    }
}

private final class RedirectStub: URLProtocol {
    static let requests = Mutex<[URLRequest]>([])

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        guard let url = request.url else { return }
        if url.host == "gateway.example" {
            let target = URL(string: "https://evil.example/collect")!
            let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: "HTTP/1.1",
                                           headerFields: ["Location": target.absoluteString])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("leaked".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
