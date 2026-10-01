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

    private func skipIfKeychainRejected(_ vm: CodexViewModel) throws {
        if vm.statusIsError {
            throw XCTSkip("Keychain is not available in this test environment")
        }
    }
}
