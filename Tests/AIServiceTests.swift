import XCTest
@testable import Core
@testable import ServicesAI

@MainActor
final class AIServiceTests: XCTestCase {
    
    func testGeminiProviderContract() {
        let provider = GeminiAIProvider.make(apiKey: "test-key")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.id, "gemini")
        XCTAssertEqual(provider?.displayName, "Gemini (Google)")
        XCTAssertTrue(provider?.isAvailable == true)
    }
    
    func testGrokProviderContractUsesCurrentModelPath() {
        let provider = GrokAIProvider.make(apiKey: "test-key")
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.id, "grok")
        XCTAssertTrue(provider?.isAvailable == true)
    }
    
    func testMockProviderReturnsResponse() async throws {
        let bus = EventBus()
        let logger = LoggerService()
        let flags = FeatureFlags()
        let service = AIService(
            provider: MockAIProvider(),
            eventBus: bus,
            logger: logger,
            featureFlags: flags
        )
        let response = try await service.complete(prompt: "Hello Quicksilver")
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertEqual(response.finishReason, .stop)
    }
    
    func testDisabledFlagBlocksNonMockProvider() async {
        let bus = EventBus()
        let logger = LoggerService()
        let flags = FeatureFlags()
        flags.set("aiServiceEnabled", enabled: false)
        
        let service = AIService(
            provider: AlwaysOnStubProvider(),
            eventBus: bus,
            logger: logger,
            featureFlags: flags
        )
        
        do {
            _ = try await service.complete(prompt: "should fail")
            XCTFail("Expected unsupportedFeature when AI is disabled for non-mock provider")
        } catch let error as AppError {
            if case .unsupportedFeature = error {
                // expected
            } else {
                XCTFail("Unexpected AppError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testMockAllowedWhenFlagDisabled() async throws {
        let bus = EventBus()
        let logger = LoggerService()
        let flags = FeatureFlags()
        flags.set("aiServiceEnabled", enabled: false)
        
        let service = AIService(
            provider: MockAIProvider(),
            eventBus: bus,
            logger: logger,
            featureFlags: flags
        )
        let response = try await service.complete(prompt: "mock still works")
        XCTAssertFalse(response.content.isEmpty)
    }
    
    func testEmptyResponseIsRejected() async {
        let bus = EventBus()
        let logger = LoggerService()
        let flags = FeatureFlags()
        flags.set("aiServiceEnabled", enabled: true)
        
        let service = AIService(
            provider: EmptyContentProvider(),
            eventBus: bus,
            logger: logger,
            featureFlags: flags
        )
        
        do {
            _ = try await service.complete(prompt: "anything")
            XCTFail("Expected empty response rejection")
        } catch let error as AppError {
            if case .aiRequestFailed(let reason) = error {
                XCTAssertTrue(reason.contains("Empty"))
            } else {
                XCTFail("Unexpected AppError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testAIRequestFailureDoesNotExposeDetails() {
        let error = AppError.aiRequestFailed("secret provider payload")
        XCTAssertEqual(error.localizedDescription, "AI request failed. Please try again.")
        XCTAssertFalse(error.localizedDescription.contains("secret provider payload"))
    }
    
    func testPersonaAwareCompleteBuildsResponse() async throws {
        let bus = EventBus()
        let logger = LoggerService()
        let flags = FeatureFlags()
        let service = AIService(
            provider: MockAIProvider(),
            eventBus: bus,
            logger: logger,
            featureFlags: flags
        )
        let response = try await service.complete(
            userMessage: "Ship the vertical slice",
            personaSystemPrompt: "You are Forge.",
            preferredTemperature: 0.3,
            maxTokensHint: 512
        )
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertEqual(response.finishReason, .stop)
    }

    func testClearAllAPIKeysRemovesKeysAndResetsProvider() {
        let bus = EventBus()
        let logger = LoggerService()
        let flags = FeatureFlags()
        let service = AIService(eventBus: bus, logger: logger, featureFlags: flags)

        _ = service.configureGrokAPIKey("test-grok-key")
        _ = service.configureGeminiAPIKey("test-gemini-key")

        XCTAssertTrue(service.hasGrokKey)
        XCTAssertTrue(service.hasGeminiKey)

        service.clearAllAPIKeys()

        XCTAssertFalse(service.hasGrokKey)
        XCTAssertFalse(service.hasGeminiKey)
        XCTAssertEqual(service.currentProviderID, "mock")
    }
}

private struct AlwaysOnStubProvider: AIProvider {
    let id = "stub"
    let displayName = "Stub"
    let isAvailable = true
    
    func complete(_ request: AIRequest) async throws -> AIResponse {
        AIResponse(requestID: request.id, content: "stub", finishReason: .stop)
    }
}

private struct EmptyContentProvider: AIProvider {
    let id = "empty"
    let displayName = "Empty"
    let isAvailable = true
    
    func complete(_ request: AIRequest) async throws -> AIResponse {
        AIResponse(requestID: request.id, content: "   \n", finishReason: .stop)
    }
}
