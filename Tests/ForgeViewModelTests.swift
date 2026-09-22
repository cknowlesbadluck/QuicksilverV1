import XCTest
@testable import Core
@testable import Personas
@testable import Nexus
@testable import Quicksilver

@MainActor
final class ForgeViewModelTests: XCTestCase {

    private var container: DependencyContainer!
    private var viewModel: ForgeViewModel!

    override func setUp() {
        super.setUp()
        container = DependencyContainer()
        viewModel = ForgeViewModel(container: container)
    }

    override func tearDown() {
        viewModel.stopLiveRefresh()
        viewModel = nil
        container = nil
        super.tearDown()
    }

    func testInitializationAndRefresh() {
        XCTAssertEqual(viewModel.activePersonaID, "quicksilver")
        XCTAssertEqual(viewModel.activeAspect, .quicksilver)
        XCTAssertFalse(viewModel.isAwake)
        XCTAssertEqual(viewModel.overallHealthScore, 100)
        XCTAssertFalse(viewModel.instruments.isEmpty)
    }

    func testStartAndStopLiveRefresh() async throws {
        viewModel.startLiveRefresh(interval: .milliseconds(50))
        try await Task.sleep(for: .milliseconds(120))
        viewModel.stopLiveRefresh()
        // Ensure no crash or memory leak on stop
        XCTAssertNotNil(viewModel)
    }

    func testAwakenForge() async {
        XCTAssertFalse(viewModel.isAwake)
        await viewModel.awakenForge()
        XCTAssertTrue(viewModel.isAwake)
        XCTAssertEqual(viewModel.activeAspect, .forge)
        XCTAssertEqual(viewModel.activePersonaID, "forge")
    }

    func testCaptureNoteTrimmingAndCapping() async {
        await viewModel.captureNote("
 ")
        XCTAssertTrue(viewModel.sessionNotes.isEmpty)

        await viewModel.captureNote("First Note")
        XCTAssertEqual(viewModel.sessionNotes, ["First Note"])

        for i in 2...15 {
            await viewModel.captureNote("Note \(i)")
        }

        XCTAssertEqual(viewModel.sessionNotes.count, 12)
        XCTAssertEqual(viewModel.sessionNotes.first, "Note 15")
    }

    func testAskForge() async {
        let answer = await viewModel.askForge("Test query")
        XCTAssertFalse(answer.isEmpty)
        XCTAssertTrue(viewModel.isAwake)
        XCTAssertEqual(viewModel.activeAspect, .forge)
    }

    func testRunDiagnosticInstrumentNominal() async {
        let result = await viewModel.runDiagnosticInstrument()
        XCTAssertFalse(result.isEmpty)
    }

    func testInstrumentsSeverityCalculation() {
        XCTAssertEqual(viewModel.instruments.count, 4)

        let battery = viewModel.instruments.first(where: { $0.id == "battery" })
        XCTAssertNotNil(battery)
        XCTAssertEqual(battery?.label, "Power")

        let thermal = viewModel.instruments.first(where: { $0.id == "thermal" })
        XCTAssertNotNil(thermal)
        XCTAssertEqual(thermal?.label, "Thermal")

        let health = viewModel.instruments.first(where: { $0.id == "health" })
        XCTAssertNotNil(health)
        XCTAssertEqual(health?.label, "System")

        let network = viewModel.instruments.first(where: { $0.id == "network" })
        XCTAssertNotNil(network)
        XCTAssertEqual(network?.label, "Link")
        XCTAssertEqual(network?.severity, .nominal)
    }
}
