import XCTest
@testable import Quicksilver
import Core
import ServicesAI

@MainActor
final class CodexViewModelTests: XCTestCase {
    func testBindAndUnbindGrokUpdatesKeyFlagAndProviderName() throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = CodexViewModel(container: container)
        XCTAssertFalse(vm.hasGrokKey)
        XCTAssertFalse(vm.aiEnabled)
        XCTAssertEqual(vm.providerName, AIService.unboundProviderName)

        vm.grokKeyDraft = "  qs-m2-t4-grok  "
        vm.saveGrokKey()
        try skipIfKeychainRejected(vm)

        XCTAssertTrue(vm.hasGrokKey)
        XCTAssertTrue(vm.grokKeyDraft.isEmpty)
        XCTAssertEqual(vm.providerName, "Grok (xAI)")
        XCTAssertTrue(vm.aiEnabled)
        XCTAssertFalse(vm.statusIsError)

        vm.clearGrokKey()
        XCTAssertFalse(vm.hasGrokKey)
        XCTAssertEqual(vm.providerName, AIService.unboundProviderName)
        XCTAssertFalse(vm.statusIsError)
    }

    func testEmptyGrokKeyDoesNotEnableAI() throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = CodexViewModel(container: container)

        vm.grokKeyDraft = "   "
        vm.saveGrokKey()

        XCTAssertTrue(vm.statusIsError)
        XCTAssertFalse(vm.hasGrokKey)
        XCTAssertFalse(vm.aiEnabled)
        XCTAssertEqual(vm.providerName, AIService.unboundProviderName)
    }

    func testBindGatewaySuccessEnablesAIAndUnbindClears() throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = CodexViewModel(container: container)

        vm.gatewayURLDraft = " https://mercury.example.workers.dev "
        vm.gatewayTokenDraft = "  device-token-m3t6  "
        vm.bindGateway()
        try skipIfKeychainRejected(vm)

        XCTAssertTrue(vm.hasGatewayBinding)
        XCTAssertTrue(vm.gatewayTokenDraft.isEmpty)
        XCTAssertEqual(vm.providerName, "Mercury Gateway")
        XCTAssertTrue(vm.aiEnabled)
        XCTAssertFalse(vm.statusIsError)
        XCTAssertEqual(
            KeychainStore.string(forKey: AIService.gatewayBaseURLKeychainAccount),
            "https://mercury.example.workers.dev"
        )
        XCTAssertEqual(
            KeychainStore.string(forKey: GatewayAIProvider.deviceTokenKeychainAccount),
            "device-token-m3t6"
        )

        vm.unbindGateway()
        XCTAssertFalse(vm.hasGatewayBinding)
        XCTAssertEqual(vm.providerName, AIService.unboundProviderName)
        XCTAssertNil(KeychainStore.string(forKey: AIService.gatewayBaseURLKeychainAccount))
        XCTAssertNil(KeychainStore.string(forKey: GatewayAIProvider.deviceTokenKeychainAccount))
        XCTAssertFalse(vm.statusIsError)
    }

    func testBindGatewayRejectsInvalidURL() throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = CodexViewModel(container: container)

        vm.gatewayURLDraft = "http://evil.example.com"
        vm.gatewayTokenDraft = "token"
        vm.bindGateway()

        XCTAssertTrue(vm.statusIsError)
        XCTAssertFalse(vm.hasGatewayBinding)
        XCTAssertFalse(vm.aiEnabled)
        XCTAssertNil(KeychainStore.string(forKey: AIService.gatewayBaseURLKeychainAccount))
    }

    func testGatewayHealthFailureSurfacesError() async throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        container.aiService.gatewayHealthFetcher = { request in
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
        let vm = CodexViewModel(container: container)
        vm.gatewayURLDraft = "https://mercury.example.workers.dev"
        await vm.testGatewayConnection()

        XCTAssertTrue(vm.statusIsError)
        XCTAssertTrue(vm.statusMessage?.contains("503") == true || vm.statusMessage?.contains("failed") == true)
    }

    func testGatewayHealthSuccessClearsError() async throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        container.aiService.gatewayHealthFetcher = { request in
            XCTAssertEqual(request.url?.path, "/v1/health")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let body = Data(#"{"ok":true,"service":"mercury-gateway"}"#.utf8)
            guard let url = request.url ?? URL(string: "https://mercury.example.workers.dev/v1/health"),
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                  ) else {
                throw URLError(.badServerResponse)
            }
            return (body, response)
        }
        let vm = CodexViewModel(container: container)
        vm.gatewayURLDraft = "https://mercury.example.workers.dev"
        await vm.testGatewayConnection()

        XCTAssertFalse(vm.statusIsError)
        XCTAssertTrue(vm.statusMessage?.contains("reachable") == true)
    }

    private func skipIfKeychainRejected(_ vm: CodexViewModel) throws {
        if vm.statusIsError {
            throw XCTSkip("Keychain is not available in this test environment")
        }
    }
}
