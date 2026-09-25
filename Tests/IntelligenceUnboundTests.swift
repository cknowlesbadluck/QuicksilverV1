import XCTest
@testable import Core
@testable import ServicesAI

/// M1-T3: with no bound provider (or intelligence switched off) the user sees an explicit
/// "Intelligence unbound" state, never fabricated mock text.
@MainActor
final class IntelligenceUnboundTests: XCTestCase {

    private func makeUnboundService(aiEnabled: Bool) -> AIService {
        let flags = FeatureFlags()
        flags.set("aiServiceEnabled", enabled: aiEnabled)
        return AIService(
            primary: nil,
            secondary: nil,
            eventBus: EventBus(),
            logger: LoggerService(),
            featureFlags: flags
        )
    }

    func testNoKeyYieldsApiKeyMissing() async {
        let service = makeUnboundService(aiEnabled: true)
        do {
            let response = try await service.complete(prompt: "Hello Quicksilver")
            XCTFail("Unbound service must not return text, got: \(response.content)")
        } catch let error as AppError {
            guard case .apiKeyMissing = error else {
                return XCTFail("Expected apiKeyMissing, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        XCTAssertNil(service.lastResponse)
        XCTAssertFalse(service.isProcessing)
    }

    func testNoKeyWithIntelligenceDisabledStillYieldsApiKeyMissing() async {
        let service = makeUnboundService(aiEnabled: false)
        do {
            _ = try await service.complete(prompt: "Hello Quicksilver")
            XCTFail("Unbound service must not return text")
        } catch let error as AppError {
            guard case .apiKeyMissing = error else {
                return XCTFail("Expected apiKeyMissing, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testPersonaAwareCompleteIsAlsoUnbound() async {
        let service = makeUnboundService(aiEnabled: true)
        do {
            _ = try await service.complete(userMessage: "Ship it", personaSystemPrompt: "You are Forge.")
            XCTFail("Unbound service must not return text")
        } catch {
            XCTAssertEqual(AppError.unboundNotice(for: error), AppError.unboundNotice)
        }
    }

    func testUnboundServiceReportsUnboundProvider() {
        let service = makeUnboundService(aiEnabled: true)
        XCTAssertFalse(service.isBound)
        XCTAssertEqual(service.currentProviderID, AIService.unboundProviderID)
        XCTAssertEqual(service.currentProviderName, AIService.unboundProviderName)
        XCTAssertNil(service.fallbackProviderName)
        XCTAssertNotEqual(service.currentProviderID, MockAIProvider().id)
    }

    func testBoundServiceReportsProvider() {
        let service = AIService(
            primary: GeminiAIProvider.make(apiKey: "test-key"),
            secondary: nil,
            eventBus: EventBus(),
            logger: LoggerService(),
            featureFlags: FeatureFlags()
        )
        XCTAssertTrue(service.isBound)
        XCTAssertEqual(service.currentProviderID, "gemini")
    }

    func testUnboundNoticeCopyPointsToTheCodex() {
        XCTAssertEqual(AppError.apiKeyMissing.localizedDescription, AppError.unboundNotice)
        XCTAssertEqual(AppError.intelligenceDisabled.localizedDescription, AppError.dormantNotice)
        for notice in [AppError.unboundNotice, AppError.dormantNotice] {
            XCTAssertTrue(notice.hasPrefix("Intelligence unbound"))
            XCTAssertTrue(notice.contains("Codex"))
            XCTAssertFalse(notice.localizedCaseInsensitiveContains("mock"))
        }
    }

    func testUnboundNoticeOnlyForUnboundErrors() {
        XCTAssertEqual(AppError.unboundNotice(for: AppError.apiKeyMissing), AppError.unboundNotice)
        XCTAssertEqual(AppError.unboundNotice(for: AppError.intelligenceDisabled), AppError.dormantNotice)
        XCTAssertNil(AppError.unboundNotice(for: AppError.networkUnavailable))
        XCTAssertNil(AppError.unboundNotice(for: AppError.aiRequestFailed("boom")))
        XCTAssertNil(AppError.unboundNotice(for: CancellationError()))
    }
}
