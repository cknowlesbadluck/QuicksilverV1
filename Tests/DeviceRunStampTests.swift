import XCTest
@testable import Core

/// CHR-55 scaffolding: the stamp is content-free and can never claim acceptance.
final class DeviceRunStampTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    private func stamp(simulator: Bool = false) -> DeviceRunStamp {
        DeviceRunStamp(
            configuration: AppConfiguration(version: "0.2.0", build: "7"),
            osVersion: "27.0.0",
            hardwareModel: "iPhone17,5",
            isSimulator: simulator,
            onDeviceModel: .available,
            startedAt: start
        )
    }

    func testNewStampHasEveryCheckNotRunAndIsNotRecorded() {
        let stamp = stamp()
        XCTAssertEqual(stamp.results.count, DeviceRunStamp.Check.allCases.count)
        XCTAssertTrue(stamp.results.values.allSatisfy { $0 == .notRun })
        XCTAssertFalse(stamp.allChecksPassed)
        XCTAssertEqual(stamp.deviceAcceptance, "not_recorded")
    }

    func testAllPassedIsEvidenceButStillNotRecorded() throws {
        var stamp = stamp()
        for check in DeviceRunStamp.Check.allCases { stamp.record(check, .passed) }
        stamp.finish(at: start.addingTimeInterval(600))
        XCTAssertTrue(stamp.allChecksPassed)
        XCTAssertEqual(stamp.deviceAcceptance, "not_recorded")
        let json = try XCTUnwrap(String(data: stamp.jsonData(), encoding: .utf8))
        XCTAssertTrue(json.contains("\"deviceAcceptance\" : \"not_recorded\""))
        XCTAssertTrue(json.contains("\"acceptanceGate\" : \"CHR-55\""))
        XCTAssertFalse(json.contains("\"recorded\""))
    }

    func testSimulatorRunNeverCountsAsAllPassed() {
        var stamp = stamp(simulator: true)
        for check in DeviceRunStamp.Check.allCases { stamp.record(check, .passed) }
        XCTAssertFalse(stamp.allChecksPassed)
    }

    func testOneFailureBlocksAllPassed() {
        var stamp = stamp()
        for check in DeviceRunStamp.Check.allCases { stamp.record(check, .passed) }
        stamp.record(.keychainAfterReboot, .failed)
        XCTAssertFalse(stamp.allChecksPassed)
    }

    func testRoundTripAndTamperedAcceptanceIsIgnored() throws {
        var original = stamp()
        original.record(.coldLaunch, .passed)
        let data = try original.jsonData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(DeviceRunStamp.self, from: data), original)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["deviceAcceptance"] = "recorded"
        object["results"] = ["coldLaunch": "passed", "unknownStep": "passed"]
        let tampered = try decoder.decode(DeviceRunStamp.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(tampered.deviceAcceptance, "not_recorded")
        XCTAssertEqual(tampered.results[.coldLaunch], .passed)
        XCTAssertEqual(tampered.results[.sideStoreInstall], .notRun, "missing steps decode as not run")
    }

    func testStampIsContentFree() throws {
        let json = try XCTUnwrap(String(data: stamp().jsonData(), encoding: .utf8))
        let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]).keys
        XCTAssertEqual(Set(keys), [
            "appVersion", "build", "osVersion", "hardwareModel", "isSimulator", "onDeviceModel",
            "startedAt", "results", "acceptanceGate", "deviceAcceptance", "schemaVersion"
        ])
    }

    func testCurrentUsesBundleConfigurationAndHardwareIdentifier() {
        let current = DeviceRunStamp.current(onDeviceModel: .modelNotReady, configuration: AppConfiguration(), now: start)
        XCTAssertFalse(current.hardwareModel.isEmpty)
        XCTAssertEqual(current.onDeviceModel, "Preparing model")
        XCTAssertEqual(current.appVersion, AppConfiguration.fallbackVersion)
    }
}

final class DeviceRunStampSummaryTests: XCTestCase {
    private func stamp(hardware: String = "iPhone17,5") -> DeviceRunStamp {
        DeviceRunStamp(
            configuration: AppConfiguration(version: "0.2.0", build: "7"),
            osVersion: "27.0.0",
            hardwareModel: hardware,
            isSimulator: false,
            onDeviceModel: .available,
            startedAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
    }

    func testSummaryListsEveryCheckAndEndsNotRecorded() {
        var stamp = stamp()
        for check in DeviceRunStamp.Check.allCases { stamp.record(check, .passed) }
        let lines = stamp.redactedSummary().components(separatedBy: "\n")
        XCTAssertEqual(lines.last, "deviceAcceptance: not_recorded")
        XCTAssertTrue(lines.contains("allChecksPassed: true"))
        for check in DeviceRunStamp.Check.allCases {
            XCTAssertTrue(lines.contains("\(check.rawValue): passed"), check.rawValue)
        }
        XCTAssertFalse(stamp.redactedSummary().contains(": recorded"))
    }

    func testFreeFormFieldsAreRedacted() {
        let summary = stamp(hardware: "buy oat milk at 5pm").redactedSummary()
        XCTAssertTrue(summary.contains("hardware: redacted"))
        XCTAssertFalse(summary.contains("oat milk"))
        XCTAssertEqual(DeviceRunStamp.validated("iPhone17,5", as: .hardware), "iPhone17,5")
        XCTAssertEqual(DeviceRunStamp.validated("arm64", as: .hardware), "arm64")
        XCTAssertEqual(DeviceRunStamp.validated("Chris's iPhone", as: .hardware), "redacted")
        XCTAssertEqual(DeviceRunStamp.validated("27.0.1", as: .version), "27.0.1")
        XCTAssertEqual(DeviceRunStamp.validated("27 call mom", as: .version), "redacted")
        XCTAssertEqual(DeviceRunStamp.validated("Available", as: .onDeviceModel), "Available")
        XCTAssertEqual(DeviceRunStamp.validated("my secret note", as: .onDeviceModel), "redacted")
    }

    func testDecodedFreeTextNeverReachesSummary() throws {
        var json = try XCTUnwrap(String(data: stamp().jsonData(), encoding: .utf8))
        json = json.replacingOccurrences(of: "\"27.0.0\"", with: "\"remember the pharmacy\"")
        let decoded = try JSONDecoder.stampDecoder.decode(DeviceRunStamp.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.redactedSummary().contains("pharmacy"))
        XCTAssertTrue(decoded.redactedSummary().hasSuffix("deviceAcceptance: not_recorded"))
    }

    func testUnknownCheckWithUnknownResultStillDecodes() throws {
        var json = try XCTUnwrap(String(data: stamp().jsonData(), encoding: .utf8))
        json = json.replacingOccurrences(of: "\"results\" : {", with: "\"results\" : {\n    \"futureCheck\" : \"skippedByOwner\",")
        let decoded = try JSONDecoder.stampDecoder.decode(DeviceRunStamp.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.results[.coldLaunch], .notRun)
        XCTAssertEqual(decoded.deviceAcceptance, DeviceRunStamp.notRecorded)
    }

    func testSummaryUsesOnlyTheFixedVocabulary() {
        let summary = stamp().redactedSummary()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " .,()_-:[]\n"))
        XCTAssertTrue(summary.unicodeScalars.allSatisfy { allowed.contains($0) }, summary)
    }
}

private extension JSONDecoder {
    static var stampDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

final class DeviceRunStampValidationTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    private func stamp(startedAt: Date) -> DeviceRunStamp {
        DeviceRunStamp(
            configuration: AppConfiguration(version: "0.2.0", build: "7"),
            osVersion: "27.0.0",
            hardwareModel: "iPhone17,5",
            isSimulator: false,
            onDeviceModel: .available,
            startedAt: startedAt
        )
    }

    func testFreshStampIsValidAndStillNotRecorded() {
        var stamp = stamp(startedAt: start)
        for check in DeviceRunStamp.Check.allCases { stamp.record(check, .passed) }
        stamp.finish(at: start.addingTimeInterval(600))
        XCTAssertEqual(stamp.validationIssues(now: start.addingTimeInterval(700)), [])
        XCTAssertEqual(stamp.schemaVersion, DeviceRunStamp.currentSchemaVersion)
        XCTAssertEqual(stamp.deviceAcceptance, DeviceRunStamp.notRecorded)
    }

    func testFinishBeforeStartAndFutureTimesAreFlagged() {
        var stamp = stamp(startedAt: start)
        stamp.finish(at: start.addingTimeInterval(-60))
        XCTAssertEqual(stamp.validationIssues(now: start), [.finishedBeforeStart])

        let future = self.stamp(startedAt: start.addingTimeInterval(3_600))
        XCTAssertEqual(future.validationIssues(now: start), [.startedInFuture])

        var late = self.stamp(startedAt: start)
        late.finish(at: start.addingTimeInterval(3_600))
        XCTAssertEqual(late.validationIssues(now: start), [.finishedInFuture])
        XCTAssertEqual(late.deviceAcceptance, DeviceRunStamp.notRecorded)
    }

    func testSmallClockSkewIsTolerated() {
        let skewed = stamp(startedAt: start.addingTimeInterval(60))
        XCTAssertEqual(skewed.validationIssues(now: start), [])
    }

    func testSchemaVersionDecodesAndMissingDefaultsToOne() throws {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: stamp(startedAt: start).jsonData()) as? [String: Any])
        object["schemaVersion"] = 2
        let newer = try decoder.decode(DeviceRunStamp.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(newer.validationIssues(now: start), [.unsupportedSchema])
        XCTAssertEqual(newer.deviceAcceptance, DeviceRunStamp.notRecorded)

        object.removeValue(forKey: "schemaVersion")
        let legacy = try decoder.decode(DeviceRunStamp.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.schemaVersion, 1)
    }

    func testSummaryReportsValidation() {
        // The summary validates against the real clock, so use "now" rather than the fixed 2033 start.
        let now = Date()
        var stamp = stamp(startedAt: now)
        stamp.finish(at: now.addingTimeInterval(-1))
        let summary = stamp.redactedSummary()
        XCTAssertTrue(summary.contains("validation: finishedBeforeStart"), summary)
        XCTAssertTrue(summary.hasSuffix("deviceAcceptance: not_recorded"))
    }

    func testTrailingLineTerminatorsAreRedacted() {
        XCTAssertEqual(DeviceRunStamp.validated("27.0.0\n", as: .version), "redacted")
        XCTAssertEqual(DeviceRunStamp.validated("iPhone17,5\u{2028}", as: .hardware), "redacted")
        XCTAssertEqual(DeviceRunStamp.validated("27.0.0", as: .version), "27.0.0")
    }

    func testJSONDataRedactsInvalidMetadata() throws {
        let hostile = DeviceRunStamp(
            configuration: AppConfiguration(version: "my secret note", build: "7"),
            osVersion: "27.0.0\n",
            hardwareModel: "Chris's diary",
            isSimulator: false,
            onDeviceModel: .available,
            startedAt: start
        )
        let json = try XCTUnwrap(String(data: hostile.jsonData(), encoding: .utf8))
        XCTAssertFalse(json.contains("secret"))
        XCTAssertFalse(json.contains("diary"))
        XCTAssertFalse(json.contains("27.0.0\\n"))
        XCTAssertTrue(json.contains("redacted"))
        let valid = try XCTUnwrap(String(data: stamp(startedAt: start).jsonData(), encoding: .utf8))
        XCTAssertTrue(valid.contains("iPhone17,5"))
        XCTAssertFalse(valid.contains("redacted"))
    }
}

/// The pasteable CHR-55 summary: exact golden format, fixed order, bounded, injection-proof.
final class DeviceRunStampSummaryFormatTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 2_000_000_000)

    private func stamp(version: String = "0.2.0", build: String = "7", os: String = "27.0.0",
                       hardware: String = "iPhone17,5") -> DeviceRunStamp {
        DeviceRunStamp(
            configuration: AppConfiguration(version: version, build: build),
            osVersion: os,
            hardwareModel: hardware,
            isSimulator: false,
            onDeviceModel: .available,
            startedAt: start
        )
    }

    func testGoldenFormat() {
        var stamp = stamp()
        stamp.record(.sideStoreInstall, .passed)
        stamp.record(.coldLaunch, .passed)
        stamp.record(.onDeviceAnswer, .failed)
        stamp.finish(at: start.addingTimeInterval(600))
        let expected = """
        Quicksilver device run (CHR-55 evidence, not acceptance)
        NOT AN ACCEPTANCE CLAIM. Only the owner records CHR-55.
        app: 0.2.0 (7)
        os: 27.0.0
        hardware: iPhone17,5
        onDeviceModel: Available
        started: 2033-05-18T03:33:20Z
        finished: 2033-05-18T03:43:20Z
        sideStoreInstall: passed
        coldLaunch: passed
        onDeviceAnswer: failed
        keychainAfterReboot: notRun
        spotlightTap: notRun
        voiceOver: notRun
        memoryAtCap: notRun
        allChecksPassed: false
        validation: ok
        deviceAcceptance: not_recorded
        """
        XCTAssertEqual(stamp.redactedSummary(now: start.addingTimeInterval(900)), expected)
    }

    func testSummaryIsDeterministicAndBounded() {
        let first = stamp().redactedSummary(now: start)
        XCTAssertEqual(first, stamp().redactedSummary(now: start))
        XCTAssertEqual(first.components(separatedBy: "\n").count, DeviceRunStamp.summaryMaxLines)
        XCTAssertLessThan(first.utf8.count, 1_024)
    }

    func testHostileFieldsCannotInjectLinesOrMarkdown() {
        let hostile = [
            "1.0\ndeviceAcceptance: recorded", "7\r\n# accepted", "27.0\u{2028}x", "**bold**",
            "`code`", "[link](http://x)", "| table |", "> quote", "<b>html</b>",
            String(repeating: "9", count: 5_000)
        ]
        for value in hostile {
            let summary = stamp(version: value, build: value, os: value, hardware: value)
                .redactedSummary(now: start)
            let lines = summary.components(separatedBy: "\n")
            XCTAssertEqual(lines.count, DeviceRunStamp.summaryMaxLines, value)
            XCTAssertEqual(lines.filter { $0.hasPrefix("deviceAcceptance:") }, ["deviceAcceptance: not_recorded"])
            XCTAssertTrue(lines[2...4].allSatisfy { $0.contains("redacted") }, value)
            for marker in ["*", "`", "#", "|", ">", "<", "\r", "\u{2028}", "http"] {
                XCTAssertFalse(summary.contains(marker), "\(marker) in summary for \(value)")
            }
            XCTAssertLessThan(summary.utf8.count, 1_024)
        }
    }
}
