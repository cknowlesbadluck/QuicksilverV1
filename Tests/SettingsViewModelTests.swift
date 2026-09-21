import XCTest
@testable import Core
@testable import ServicesAI
@testable import Quicksilver

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
        XCTAssertEqual(viewModel.grokKeyDraft, "")
        XCTAssertEqual(viewModel.geminiKeyDraft, "")
        XCTAssertNil(viewModel.statusMessage)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertTrue(viewModel.personaAutonomyEnabled)
    }

    func testSaveGrokKeyValidationAndPersistence() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        // Empty draft validation
        viewModel.grokKeyDraft = "   \n"
        viewModel.saveGrokKey()

        XCTAssertTrue(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Enter a non-empty Grok API key.")
        XCTAssertFalse(viewModel.hasGrokKey)

        // Valid key saving
        viewModel.grokKeyDraft = "grok-secret-key-123"
        viewModel.saveGrokKey()

        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Grok key saved to Keychain.")
        XCTAssertEqual(viewModel.grokKeyDraft, "")
        XCTAssertTrue(viewModel.hasGrokKey)
        XCTAssertEqual(KeychainStore.string(forKey: AIService.grokAPIKeyKeychainAccount), "grok-secret-key-123")
    }

    func testSaveGeminiKeyValidationAndPersistence() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        // Empty draft validation
        viewModel.geminiKeyDraft = ""
        viewModel.saveGeminiKey()

        XCTAssertTrue(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Enter a non-empty Gemini API key.")
        XCTAssertFalse(viewModel.hasGeminiKey)

        // Valid key saving
        viewModel.geminiKeyDraft = "gemini-secret-key-456"
        viewModel.saveGeminiKey()

        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Gemini key saved to Keychain.")
        XCTAssertEqual(viewModel.geminiKeyDraft, "")
        XCTAssertTrue(viewModel.hasGeminiKey)
        XCTAssertEqual(KeychainStore.string(forKey: AIService.geminiAPIKeyKeychainAccount), "gemini-secret-key-456")
    }

    func testClearGrokKeyRemovesCredentialAndUpdatesState() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "grok-to-clear"
        viewModel.saveGrokKey()
        XCTAssertTrue(viewModel.hasGrokKey)

        viewModel.clearGrokKey()

        XCTAssertFalse(viewModel.hasGrokKey)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Grok key removed.")
        XCTAssertNil(KeychainStore.string(forKey: AIService.grokAPIKeyKeychainAccount))
    }

    func testClearGeminiKeyRemovesCredentialAndUpdatesState() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.geminiKeyDraft = "gemini-to-clear"
        viewModel.saveGeminiKey()
        XCTAssertTrue(viewModel.hasGeminiKey)

        viewModel.clearGeminiKey()

        XCTAssertFalse(viewModel.hasGeminiKey)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "Gemini key removed.")
        XCTAssertNil(KeychainStore.string(forKey: AIService.geminiAPIKeyKeychainAccount))
    }

    func testClearAPIKeyRemovesAllCredentials() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "grok-key-1"
        viewModel.saveGrokKey()
        viewModel.geminiKeyDraft = "gemini-key-2"
        viewModel.saveGeminiKey()

        XCTAssertTrue(viewModel.hasGrokKey)
        XCTAssertTrue(viewModel.hasGeminiKey)

        viewModel.clearAPIKey()

        XCTAssertFalse(viewModel.hasGrokKey)
        XCTAssertFalse(viewModel.hasGeminiKey)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertEqual(viewModel.statusMessage, "API keys removed.")
        XCTAssertNil(KeychainStore.string(forKey: AIService.grokAPIKeyKeychainAccount))
        XCTAssertNil(KeychainStore.string(forKey: AIService.geminiAPIKeyKeychainAccount))
    }

    func testSetAIEnabledToggle() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.setAIEnabled(false)

        XCTAssertFalse(viewModel.aiEnabled)
        XCTAssertEqual(viewModel.statusMessage, "AI Service disabled (Mock only).")
        XCTAssertFalse(viewModel.statusIsError)

        viewModel.setAIEnabled(true)

        XCTAssertTrue(viewModel.aiEnabled)
        XCTAssertEqual(viewModel.statusMessage, "AI Service enabled.")
        XCTAssertFalse(viewModel.statusIsError)
    }

    func testSetPersonaAutonomyToggle() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.setPersonaAutonomy(false)

        XCTAssertFalse(viewModel.personaAutonomyEnabled)
        XCTAssertEqual(viewModel.statusMessage, "Persona autonomy disabled.")
        XCTAssertFalse(viewModel.statusIsError)

        viewModel.setPersonaAutonomy(true)

        XCTAssertTrue(viewModel.personaAutonomyEnabled)
        XCTAssertEqual(viewModel.statusMessage, "Persona autonomy enabled.")
        XCTAssertFalse(viewModel.statusIsError)
    }
}
