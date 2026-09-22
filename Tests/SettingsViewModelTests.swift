import XCTest
@testable import Core
@testable import ServicesAI
@testable import UI

@MainActor
final class SettingsViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        cleanKeys()
    }

    override func tearDown() {
        cleanKeys()
        super.tearDown()
    }

    private func cleanKeys() {
        KeychainStore.delete(forKey: AIService.grokAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: AIService.geminiAPIKeyKeychainAccount)
    }

    func testInitialStateReflectsContainerDefaults() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        XCTAssertFalse(viewModel.hasGrokKey)
        XCTAssertFalse(viewModel.hasGeminiKey)
        XCTAssertEqual(viewModel.grokKeyDraft, "")
        XCTAssertEqual(viewModel.geminiKeyDraft, "")
        XCTAssertNil(viewModel.statusMessage)
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertFalse(viewModel.personaAutonomyEnabled)
    }

    func testSaveGrokKeySuccess() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "  xai-valid-grok-key-123 \n "
        viewModel.saveGrokKey()

        XCTAssertEqual(viewModel.grokKeyDraft, "")
        XCTAssertEqual(viewModel.statusMessage, "Grok key saved to Keychain.")
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertTrue(viewModel.hasGrokKey)
    }

    func testSaveGrokKeyValidationFailure() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "   \t\n "
        viewModel.saveGrokKey()

        XCTAssertEqual(viewModel.statusMessage, "Enter a non-empty Grok API key.")
        XCTAssertTrue(viewModel.statusIsError)
        XCTAssertFalse(viewModel.hasGrokKey)
    }

    func testSaveGeminiKeySuccess() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.geminiKeyDraft = " gemini-valid-key-456 "
        viewModel.saveGeminiKey()

        XCTAssertEqual(viewModel.geminiKeyDraft, "")
        XCTAssertEqual(viewModel.statusMessage, "Gemini key saved to Keychain.")
        XCTAssertFalse(viewModel.statusIsError)
        XCTAssertTrue(viewModel.hasGeminiKey)
    }

    func testSaveGeminiKeyValidationFailure() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.geminiKeyDraft = ""
        viewModel.saveGeminiKey()

        XCTAssertEqual(viewModel.statusMessage, "Enter a non-empty Gemini API key.")
        XCTAssertTrue(viewModel.statusIsError)
        XCTAssertFalse(viewModel.hasGeminiKey)
    }

    func testClearGrokKey() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.grokKeyDraft = "temp-grok-key"
        viewModel.saveGrokKey()
        XCTAssertTrue(viewModel.hasGrokKey)

        viewModel.clearGrokKey()

        XCTAssertFalse(viewModel.hasGrokKey)
        XCTAssertEqual(viewModel.statusMessage, "Grok key removed.")
        XCTAssertFalse(viewModel.statusIsError)
    }

    func testClearGeminiKey() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.geminiKeyDraft = "temp-gemini-key"
        viewModel.saveGeminiKey()
        XCTAssertTrue(viewModel.hasGeminiKey)

        viewModel.clearGeminiKey()

        XCTAssertFalse(viewModel.hasGeminiKey)
        XCTAssertEqual(viewModel.statusMessage, "Gemini key removed.")
        XCTAssertFalse(viewModel.statusIsError)
    }

    func testSetAIEnabledTogglesFlagAndStatus() {
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

    func testSetPersonaAutonomyShim() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        viewModel.setPersonaAutonomy(true)

        XCTAssertFalse(viewModel.personaAutonomyEnabled)
        XCTAssertEqual(viewModel.statusMessage, "Aspect autonomy is Brain-owned and always active.")
        XCTAssertFalse(viewModel.statusIsError)
    }

    func testRefreshSyncsWithContainerState() {
        let container = DependencyContainer()
        let viewModel = SettingsViewModel(container: container)

        XCTAssertFalse(viewModel.hasGrokKey)

        _ = container.aiService.configureGrokAPIKey("direct-configured-key")
        viewModel.refresh()

        XCTAssertTrue(viewModel.hasGrokKey)
    }
}
