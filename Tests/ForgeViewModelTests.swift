#if canImport(Quicksilver)
import XCTest
@testable import Core
@testable import Memory
@testable import Personas
@testable import Nexus
@testable import Quicksilver

@MainActor
final class ForgeViewModelTests: XCTestCase {

    func testInitialState() {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        XCTAssertTrue(viewModel.sessionNotes.isEmpty)
        XCTAssertFalse(viewModel.activePersonaID.isEmpty)
        XCTAssertFalse(viewModel.instruments.isEmpty)
    }

    func testCaptureNoteWithEmptyOrWhitespaceInput() async {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        await viewModel.captureNote("")
        XCTAssertTrue(viewModel.sessionNotes.isEmpty)

        await viewModel.captureNote("   \t\n  ")
        XCTAssertTrue(viewModel.sessionNotes.isEmpty)
    }

    func testCaptureNoteWithValidText() async {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        await viewModel.captureNote("  Refactor memory allocation pipeline  ")

        XCTAssertEqual(viewModel.sessionNotes, ["Refactor memory allocation pipeline"])
    }

    func testCaptureNotePersistsToBrainMemory() async {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)
        let noteText = "Verify thread safety in Nexus"

        await viewModel.captureNote(noteText)

        let snapshot = container.brain.retrieveSnapshot(limit: 10)
        let found = snapshot.contains { $0.value.contains(noteText) }
        XCTAssertTrue(found, "Captured note should be recorded in MercuryBrain memory")
    }

    func testCaptureNoteOrdering() async {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        await viewModel.captureNote("First note")
        await viewModel.captureNote("Second note")

        XCTAssertEqual(viewModel.sessionNotes, ["Second note", "First note"])
    }

    func testCaptureNoteCapacityCappedAtTwelve() async {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        for i in 1...15 {
            await viewModel.captureNote("Note \(i)")
        }

        XCTAssertEqual(viewModel.sessionNotes.count, 12)
        XCTAssertEqual(viewModel.sessionNotes.first, "Note 15")
        XCTAssertEqual(viewModel.sessionNotes.last, "Note 4")
    }

    func testAwakenForge() async {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        await viewModel.awakenForge()

        XCTAssertTrue(viewModel.isAwake)
        XCTAssertEqual(viewModel.activeAspect, .forge)
    }

    func testAskForge() async {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        let answer = await viewModel.askForge("Report workshop readiness")

        XCTAssertFalse(answer.isEmpty)
    }

    func testStartAndStopLiveRefresh() {
        let container = DependencyContainer()
        let viewModel = ForgeViewModel(container: container)

        viewModel.startLiveRefresh(interval: .milliseconds(100))
        viewModel.stopLiveRefresh()
    }
}
#endif
