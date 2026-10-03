import XCTest
@testable import Core
@testable import ServicesAI

/// M3-T6: gateway URL + device token bind, health check, unbind (no real network).
@MainActor
final class GatewayBindTests: XCTestCase {
    private let urlKey = AIService.gatewayBaseURLKeychainAccount
    private let tokenKey = GatewayAIProvider.deviceTokenKeychainAccount
    private var previousURL: String?
    private var previousToken: String?

    override func setUp() async throws {
        try await super.setUp()
        previousURL = KeychainStore.string(forKey: urlKey)
        previousToken = KeychainStore.string(forKey: tokenKey)
        KeychainStore.delete(forKey: urlKey)
        KeychainStore.delete(forKey: tokenKey)
    }

    override func tearDown() async throws {
        KeychainStore.delete(forKey: urlKey)
        KeychainStore.delete(forKey: tokenKey)
        if let previousURL {
            _ = KeychainStore.set(previousURL, forKey: urlKey)
        }
        if let previousToken {
            _ = KeychainStore.set(previousToken, forKey: tokenKey)
        }
        try await super.tearDown()
    }

    private func requireKeychain() throws {
        let probe = "gateway.bind.probe.\(UUID().uuidString)"
        guard KeychainStore.set("1", forKey: probe) else {
            throw XCTSkip("Keychain is not available in this test environment")
        }
        KeychainStore.delete(forKey: probe)
    }

    private func makeService() -> AIService {
        let flags = FeatureFlags()
        flags.set("aiServiceEnabled", enabled: false)
        return AIService(
            primary: nil,
            secondary: nil,
            eventBus: EventBus(),
            logger: LoggerService(subsystem: "com.quicksilver.tests"),
            featureFlags: flags
        )
    }

    func testConfigureGatewayRejectsNonHTTPS() {
        let service = makeService()
        let error = service.configureGateway(
            baseURL: "http://evil.example.com",
            deviceToken: "token"
        )
        XCTAssertEqual(error, .invalidURL(.notHTTPS))
        XCTAssertFalse(service.hasGatewayBinding)
    }

    func testConfigureGatewayBindAndClear() throws {
        try requireKeychain()
        let service = makeService()
        let error = service.configureGateway(
            baseURL: " https://mercury.example.workers.dev ",
            deviceToken: "  device-token  "
        )
        XCTAssertNil(error)
        XCTAssertTrue(service.hasGatewayBinding)
        XCTAssertEqual(service.currentProviderName, "Mercury Gateway")
        XCTAssertEqual(
            KeychainStore.string(forKey: urlKey),
            "https://mercury.example.workers.dev"
        )
        XCTAssertEqual(KeychainStore.string(forKey: tokenKey), "device-token")

        service.clearGateway()
        XCTAssertFalse(service.hasGatewayBinding)
        XCTAssertEqual(service.currentProviderName, AIService.unboundProviderName)
        XCTAssertNil(KeychainStore.string(forKey: urlKey))
        XCTAssertNil(KeychainStore.string(forKey: tokenKey))
    }

    func testHealthFailureSurfacesStatus() async {
        let service = makeService()
        service.gatewayHealthFetcher = { request in
            guard let url = request.url ?? URL(string: "https://mercury.example.workers.dev/v1/health"),
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }
            return (Data(), response)
        }
        let result = await service.testGatewayHealth(baseURL: "https://mercury.example.workers.dev")
        XCTAssertEqual(result, .failure(.healthFailed(status: 503)))
    }

    func testHealthSuccessRequiresMercuryService() async {
        let service = makeService()
        service.gatewayHealthFetcher = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/v1/health")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let body = Data(#"{"ok":true,"service":"mercury-gateway"}"#.utf8)
            guard let url = request.url ?? URL(string: "https://mercury.example.workers.dev/v1/health"),
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }
            return (body, response)
        }
        let result = await service.testGatewayHealth(baseURL: "https://mercury.example.workers.dev")
        switch result {
        case .success(let health):
            XCTAssertTrue(health.isMercury)
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testHealthRejectsNonMercuryService() async {
        let service = makeService()
        service.gatewayHealthFetcher = { request in
            let body = Data(#"{"ok":true,"service":"other"}"#.utf8)
            guard let url = request.url ?? URL(string: "https://mercury.example.workers.dev/v1/health"),
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                  ) else {
                throw URLError(.badServerResponse)
            }
            return (body, response)
        }
        let result = await service.testGatewayHealth(baseURL: "https://mercury.example.workers.dev")
        XCTAssertEqual(result, .failure(.notMercury))
    }

    func testEmptyTokenRejected() {
        let service = makeService()
        let error = service.configureGateway(
            baseURL: "https://mercury.example.workers.dev",
            deviceToken: "   "
        )
        XCTAssertEqual(error, .emptyToken)
    }
}
