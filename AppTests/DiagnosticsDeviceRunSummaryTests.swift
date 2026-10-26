import XCTest
import Core
@testable import Quicksilver

@MainActor
final class DiagnosticsDeviceRunSummaryTests: XCTestCase {
    private let config = AppConfiguration(infoDictionary: [
        "CFBundleShortVersionString": "0.2.0",
        "CFBundleVersion": "7"
    ])

    func testSummaryIsRedactedEvidenceNeverAcceptance() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let text = DiagnosticsViewModel.deviceRunSummary(onDeviceModel: .available, configuration: config, now: now)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        XCTAssertEqual(lines.last, "deviceAcceptance: not_recorded")
        XCTAssertTrue(text.contains("NOT AN ACCEPTANCE CLAIM"))
        XCTAssertTrue(text.contains("app: 0.2.0 (7)"))
        XCTAssertTrue(text.contains("allChecksPassed: false"), "the screen never marks checks as passed")
        XCTAssertLessThanOrEqual(lines.count, DeviceRunStamp.summaryMaxLines)
        for check in DeviceRunStamp.Check.allCases {
            XCTAssertTrue(text.contains("\(check.rawValue): notRun"))
        }
    }

    func testSummaryIsDeterministicForAFixedClock() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(
            DiagnosticsViewModel.deviceRunSummary(onDeviceModel: .available, configuration: config, now: now),
            DiagnosticsViewModel.deviceRunSummary(onDeviceModel: .available, configuration: config, now: now)
        )
    }
}
