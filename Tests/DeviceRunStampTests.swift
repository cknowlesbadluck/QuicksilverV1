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
            "startedAt", "results", "acceptanceGate", "deviceAcceptance"
        ])
    }

    func testCurrentUsesBundleConfigurationAndHardwareIdentifier() {
        let current = DeviceRunStamp.current(onDeviceModel: .modelNotReady, configuration: AppConfiguration(), now: start)
        XCTAssertFalse(current.hardwareModel.isEmpty)
        XCTAssertEqual(current.onDeviceModel, "Preparing model")
        XCTAssertEqual(current.appVersion, AppConfiguration.fallbackVersion)
    }
}
