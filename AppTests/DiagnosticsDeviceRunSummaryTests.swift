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

    /// Content allowlist: the shared text is the two fixed header lines plus `key: value` lines
    /// with known keys only, so no memory, message or free text can ride along.
    func testSharedTextUsesOnlyAllowlistedKeys() {
        let allowedKeys = Set(["app", "os", "hardware", "onDeviceModel", "started", "finished",
                               "allChecksPassed", "validation", "deviceAcceptance"])
            .union(DeviceRunStamp.Check.allCases.map(\.rawValue))
        let text = DiagnosticsViewModel.deviceRunSummary(
            onDeviceModel: .available, configuration: config, now: Date(timeIntervalSince1970: 1_800_000_000))
        let lines = text.components(separatedBy: "\n")
        XCTAssertTrue(lines[0].hasPrefix("Quicksilver device run (CHR-55 evidence, not acceptance)"))
        XCTAssertEqual(lines[1], "NOT AN ACCEPTANCE CLAIM. Only the owner records CHR-55.")
        for line in lines.dropFirst(2) {
            let key = line.components(separatedBy: ": ").first ?? ""
            XCTAssertTrue(allowedKeys.contains(key), "unexpected line in shared evidence: key '\(key)'")
        }
    }
}
