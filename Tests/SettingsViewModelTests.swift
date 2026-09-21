import XCTest
@testable import Core
@testable import ServicesAI
#if canImport(UI)
@testable import UI
#endif
#if canImport(Quicksilver)
@testable import Quicksilver
#endif

@MainActor
final class SettingsViewModelTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        KeychainStore.delete(forKey: AIService.grokAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: AIService.geminiAPIKeyKeychainAccount)
    }

    override func tearDown() async throws {
        KeychainStore.delete(forKey: AIService.grokAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: AIService.geminiAPIKeyKeychainAccount)
        try await super.tearDown()
    }

    func testInitialState() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        XCTAssertFalse(viewModel.hasGrokKey)
        XCTAssertFalse(viewModel.hasGeminiKey)
        XCTAssertTrue(viewModel.grokKeyDraft.isEmpty)
        XCTAssertTrue(viewModel.geminiKeyDraft.isEmpty)
        XCTAssertNil(viewModel.statusMessage)
        XCTAssertFalse(viewModel.statusIsError)
    }

    func testSaveGrokKeyEmptyValidation() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "   \n "
        viewModel.saveGrokKey()

        XCTAssertTrue(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Enter a non-empty Grok API key.")
        XCTAssertFalse(viewModel.hasGrokKey)
    }

    func testSaveGrokKeyValid() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = " xai-test-key-123 "
        viewModel.saveGrokKey()

        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Grok key saved to Keychain.")
        XCTAssertTrue(viewModel.grokKeyDraft.isEmpty)
        XCTAssertTrue(viewModel.hasGrokKey)
    }

    func testSaveGeminiKeyEmptyValidation() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.geminiKeyDraft = ""
        viewModel.saveGeminiKey()

        XCTAssertTrue(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Enter a non-empty Gemini API key.")
        XCTAssertFalse(viewModel.hasGeminiKey)
    }

    func testSaveGeminiKeyValid() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.geminiKeyDraft = " gemini-test-key-456 "
        viewModel.saveGeminiKey()

        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Gemini key saved to Keychain.")
        XCTAssertTrue(viewModel.geminiKeyDraft.isEmpty)
        XCTAssertTrue(viewModel.hasGeminiKey)
    }

    func testClearGrokKey() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "xai-test-key"
        viewModel.saveGrokKey()
        XCTAssertTrue(viewModel.hasGrokKey)

        viewModel.clearGrokKey()

        XCTAssertFalse(viewModel.hasGrokKey)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Grok key removed.")
    }

    func testClearGeminiKey() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.geminiKeyDraft = "gemini-test-key"
        viewModel.saveGeminiKey()
        XCTAssertTrue(viewModel.hasGeminiKey)

        viewModel.clearGeminiKey()

        XCTAssertFalse(viewModel.hasGeminiKey)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Gemini key removed.")
    }

    func testClearAPIKeyRemovesAllKeysAndDrafts() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "grok-key"
        viewModel.saveGrokKey()

        viewModel.geminiKeyDraft = "gemini-key"
        viewModel.saveGeminiKey()

        XCTAssertTrue(viewModel.hasGrokKey)
        XCTAssertTrue(viewModel.hasGeminiKey)

        viewModel.grokKeyDraft = "draft-grok"
        viewModel.geminiKeyDraft = "draft-gemini"

        viewModel.clearAPIKey()

        XCTAssertFalse(viewModel.hasGrokKey)
        XCTAssertFalse(viewModel.hasGeminiKey)
        XCTAssertTrue(viewModel.grokKeyDraft.isEmpty)
        XCTAssertTrue(viewModel.geminiKeyDraft.isEmpty)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "API keys removed.")
    }

    func testSetAIEnabledToggle() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.setAIEnabled(false)

        XCTAssertFalse(viewModel.aiEnabled)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "AI Service disabled (Mock only).")

        viewModel.setAIEnabled(true)

        XCTAssertTrue(viewModel.aiEnabled)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "AI Service enabled.")
    }

    func testSetPersonaAutonomyToggle() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.setPersonaAutonomy(false)

        XCTAssertFalse(viewModel.personaAutonomyEnabled)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Persona autonomy disabled.")

        viewModel.setPersonaAutonomy(true)

        XCTAssertTrue(viewModel.personaAutonomyEnabled)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Persona autonomy enabled.")
    }
}
