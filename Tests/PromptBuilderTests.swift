import XCTest
@testable import Core
@testable import ServicesAI

final class PromptBuilderTests: XCTestCase {

    func testBuildsSystemWithContext() {
        let builder = PromptBuilder()
        let result = builder.build(
            personaSystemPrompt: "You are Forge.",
            preferredTemperature: 0.3,
            maxTokensHint: 512,
            userMessage: "Status?",
            assembledContext: "Active persona: Forge"
        )

        XCTAssertTrue(result.systemPrompt.contains("You are Forge."))
        XCTAssertTrue(result.systemPrompt.contains("Active Context"))
        XCTAssertTrue(result.systemPrompt.contains("Active persona: Forge"))
        XCTAssertTrue(result.systemPrompt.contains("<context>"))
        XCTAssertTrue(result.systemPrompt.contains("</context>"))
        XCTAssertEqual(result.userPrompt, "Status?")
        XCTAssertEqual(result.temperature, 0.3, accuracy: 0.001)
        XCTAssertEqual(result.maxTokens, 512)
    }

    func testOmitsEmptyContext() {
        let builder = PromptBuilder()
        let result = builder.build(
            personaSystemPrompt: "You are Quicksilver.",
            preferredTemperature: 0.7,
            maxTokensHint: 1024,
            userMessage: "Hello",
            assembledContext: nil
        )
        XCTAssertFalse(result.systemPrompt.contains("Active Context"))
        XCTAssertFalse(result.systemPrompt.contains("<context>"))
        XCTAssertFalse(result.systemPrompt.contains("</context>"))
    }
}

final class ContextAssemblerTests: XCTestCase {

    func testAssemblesCompactBlock() {
        let assembler = ContextAssembler()
        let text = assembler.assemble(.init(
            personaDisplayName: "Eternal",
            recentMemorySnippets: ["prefers dark mode", "working on Nexus"],
            latestInsightTitles: ["Low battery"],
            deviceSummary: "Battery 18%, thermal nominal"
        ))

        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("Eternal"))
        XCTAssertTrue(text!.contains("prefers dark mode"))
        XCTAssertTrue(text!.contains("Low battery"))
        XCTAssertTrue(text!.contains("Battery 18%"))
    }

    func testEmptyInputReturnsNil() {
        let assembler = ContextAssembler()
        XCTAssertNil(assembler.assemble(.init()))
    }
}

final class ResponseValidatorTests: XCTestCase {

    func testRejectsEmpty() {
        let response = AIResponse(requestID: UUID(), content: "   ")
        if case .reject = ResponseValidator.validate(response) {
            // expected
        } else {
            XCTFail("Expected reject")
        }
    }

    func testAcceptsNormal() {
        let response = AIResponse(requestID: UUID(), content: "Forge ready.")
        if case .accept(let accepted) = ResponseValidator.validate(response) {
            XCTAssertEqual(accepted.content, "Forge ready.")
        } else {
            XCTFail("Expected accept")
        }
    }
}
