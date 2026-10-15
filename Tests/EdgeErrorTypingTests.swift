import Security
import XCTest
@testable import Core
@testable import ServicesAI

/// Hardening: malformed wire data and Keychain read failures surface as typed errors.
@MainActor
final class EdgeErrorTypingTests: XCTestCase {
    private struct ThrowingProvider: AIProvider {
        let error: Error
        let id = "throwing"
        let displayName = "Throwing"
        let isAvailable = true
        var trainsOnPrompts: Bool { false }
        func complete(_ request: AIRequest) async throws -> AIResponse { throw error }
    }

    private func service(throwing error: Error) -> AIService {
        let flags = FeatureFlags(defaults: UserDefaults(suiteName: "EdgeErrors.\(UUID().uuidString)") ?? .standard)
        flags.set("aiServiceEnabled", enabled: true)
        let svc = AIService(primary: ThrowingProvider(error: error), secondary: nil,
                            eventBus: EventBus(), logger: LoggerService(), featureFlags: flags)
        svc.retrySleep = { _ in }
        return svc
    }

    private func assertMalformed(_ error: Error, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await service(throwing: error).complete(AIRequest(prompt: "explain recursion"))
            XCTFail("expected failure", file: file, line: line)
        } catch {
            guard case .aiRequestFailed(let reason)? = error as? AppError else {
                return XCTFail("Untyped error leaked: \(error)", file: file, line: line)
            }
            XCTAssertEqual(reason, AIService.malformedResponseReason, file: file, line: line)
        }
    }

    func testTruncatedGatewayStreamIsTyped() async {
        await assertMalformed(GatewayWireDecodeError.incompleteStream)
    }

    func testMalformedGatewayEventIsTyped() async {
        await assertMalformed(GatewayWireDecodeError.malformedEvent("delta"))
        await assertMalformed(GatewayWireDecodeError.empty)
    }

    func testJSONDecodingErrorIsTyped() async {
        let decoding = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "truncated"))
        await assertMalformed(decoding)
    }

    func testTypedErrorsPassThroughUnchanged() {
        guard case .budgetExhausted? = AIService.typedSurface(AppError.budgetExhausted) as? AppError else {
            return XCTFail("AppError must pass through")
        }
        XCTAssertTrue(AIService.typedSurface(URLError(.networkConnectionLost)) is URLError)
    }

    func testKeychainStatusMapping() throws {
        XCTAssertNil(try KeychainStore.interpret(status: errSecItemNotFound, item: nil), "Absent is not an error")
        XCTAssertEqual(try KeychainStore.interpret(status: errSecSuccess, item: Data([1]) as CFData), Data([1]))
        XCTAssertThrowsError(try KeychainStore.interpret(status: errSecInteractionNotAllowed, item: nil)) {
            XCTAssertEqual($0 as? KeychainStore.ReadError, .locked)
        }
        XCTAssertThrowsError(try KeychainStore.interpret(status: errSecAuthFailed, item: nil)) {
            XCTAssertEqual($0 as? KeychainStore.ReadError, .failed(errSecAuthFailed))
        }
        XCTAssertThrowsError(try KeychainStore.interpret(status: errSecSuccess, item: nil)) {
            XCTAssertEqual($0 as? KeychainStore.ReadError, .failed(errSecDecode))
        }
    }
}
