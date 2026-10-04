import XCTest
@testable import Quicksilver
import Core

@MainActor
final class AskViewModelTests: XCTestCase {
    func testSubmitPersistsUserAndAssistantTurns() async throws {
        let container = try ViewModelTestSupport.makeContainer(
            provider: ScriptedProvider(reply: "Ready.", failure: nil),
            testCase: self
        )
        container.featureFlags.set("aiServiceEnabled", enabled: true)
        await container.memoryManager.load()
        let vm = AskViewModel(container: container)
        vm.draft = "  build a shelf  "

        await vm.submit()

        XCTAssertEqual(vm.turns.map(\.role), [.user, .assistant])
        XCTAssertEqual(vm.turns.map(\.text), ["build a shelf", "Ready."])
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.unboundNotice)
        XCTAssertFalse(vm.isProcessing)

        let values = container.memoryManager.items.map(\.value)
        XCTAssertTrue(values.contains("build a shelf"))
        XCTAssertTrue(values.contains("Ready."))
    }

    func testProviderErrorSetsErrorMessage() async throws {
        let container = try ViewModelTestSupport.makeContainer(
            provider: ScriptedProvider(reply: "", failure: AppError.aiRequestFailed("down")),
            testCase: self
        )
        container.featureFlags.set("aiServiceEnabled", enabled: true)
        let vm = AskViewModel(container: container)
        vm.draft = "diagnose the build"

        await vm.submit()

        let expected = AppError.aiRequestFailed("down").localizedDescription
        XCTAssertEqual(vm.errorMessage, expected)
        XCTAssertNil(vm.unboundNotice)
        XCTAssertEqual(vm.turns.map(\.role), [.user])
        XCTAssertFalse(vm.isProcessing)
    }

    func testHistorySurvivesAspectSwitch() async throws {
        let container = try ViewModelTestSupport.makeContainer(
            provider: ScriptedProvider(reply: "Still here.", failure: nil),
            testCase: self
        )
        container.featureFlags.set("aiServiceEnabled", enabled: true)
        await container.memoryManager.load()

        let originalAspect = container.personaManager.activePersonaID
        let seededText = "seeded-scoped-turn-before-switch"
        await container.memoryManager.set(
            key: "chat.seeded.scoped.history",
            value: seededText,
            category: .conversation,
            metadata: [
                "role": "user",
                "persona": originalAspect,
                "aspect": originalAspect
            ],
            importanceBoost: 0.5,
            personaScope: originalAspect
        )

        let vm = AskViewModel(container: container)
        vm.draft = "keep this across aspects"

        await vm.submit()
        let recordedAspect = container.memoryManager.items
            .first { $0.metadata["role"] == "assistant" }?
            .metadata["aspect"]
        let otherAspect = recordedAspect == "forge" ? "eternal" : "forge"
        try await container.personaManager.switchTo(id: otherAspect)
        XCTAssertNotEqual(container.personaManager.activePersonaID, recordedAspect)

        await vm.loadHistory()

        XCTAssertTrue(vm.turns.map(\.text).contains(seededText))
        XCTAssertTrue(vm.turns.map(\.text).contains("keep this across aspects"))
        XCTAssertTrue(vm.turns.map(\.text).contains("Still here."))

        let submitTexts = Set(["keep this across aspects", "Still here."])
        let submitTurns = container.memoryManager.items.filter {
            $0.category == .conversation && submitTexts.contains($0.value)
        }
        XCTAssertEqual(submitTurns.count, 2)
        XCTAssertTrue(submitTurns.allSatisfy { $0.personaScope == nil })
        XCTAssertNotNil(recordedAspect)
        XCTAssertTrue(submitTurns.allSatisfy { $0.metadata["aspect"] == recordedAspect })

        let seeded = container.memoryManager.items.first { $0.value == seededText }
        XCTAssertEqual(seeded?.personaScope, originalAspect)
    }

    func testUnboundSubmitShowsNotice() async throws {
        ViewModelTestSupport.isolateProviderKeychain(testCase: self)
        let container = try ViewModelTestSupport.makeContainer(provider: nil, testCase: self)
        let vm = AskViewModel(container: container)
        vm.draft = "hello"

        await vm.submit()

        XCTAssertEqual(vm.unboundNotice, AppError.unboundNotice)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.turns.map(\.role), [.user])
        XCTAssertFalse(vm.isProcessing)
    }
}

private struct ScriptedProvider: AIProvider {
    let reply: String
    let failure: AppError?
    let id = "scripted"
    let displayName = "Scripted"
    let isAvailable = true

    func complete(_ request: AIRequest) async throws -> AIResponse {
        if let failure {
            throw failure
        }
        return AIResponse(requestID: request.id, content: reply)
    }
}
