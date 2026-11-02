import Foundation
import XCTest
@testable import Core

/// CHR-55 stays `not_recorded` in code. Every stamp the app can build, for every combination of
/// step results on device and simulator, says so in both the JSON and the summary. No
/// production source may write any other acceptance value.
final class DeviceAcceptanceGuardTests: XCTestCase {
    private static let forbiddenValues = ["accepted", "passed", "recorded", "approved", "complete"]

    func testEveryResultCombinationStaysNotRecorded() throws {
        let checks = DeviceRunStamp.Check.allCases
        let outcomes: [DeviceRunStamp.Result] = [.notRun, .passed, .failed]
        let combinations = Int(pow(Double(outcomes.count), Double(checks.count)))
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        for simulator in [false, true] {
            for index in 0..<combinations {
                var stamp = DeviceRunStamp(
                    configuration: AppConfiguration(version: "0.2.0", build: "7"),
                    osVersion: "27.0.0",
                    hardwareModel: "iPhone17,5",
                    isSimulator: simulator,
                    onDeviceModel: .available,
                    startedAt: start
                )
                var code = index
                for check in checks {
                    stamp.record(check, outcomes[code % outcomes.count])
                    code /= outcomes.count
                }
                stamp.finish(at: start.addingTimeInterval(600))
                XCTAssertEqual(stamp.deviceAcceptance, "not_recorded")
                XCTAssertEqual(stamp.redactedSummary().split(separator: "\n").last, "deviceAcceptance: not_recorded")
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: stamp.jsonData()) as? [String: Any])
                XCTAssertEqual(json["deviceAcceptance"] as? String, "not_recorded")
                XCTAssertEqual(json["acceptanceGate"] as? String, "CHR-55")
            }
        }
    }

    /// Any `deviceAcceptance` key or label next to a literal other than "not_recorded" fails, as
    /// does an acceptance word in `DeviceRunStamp.notRecorded` itself.
    func testNoSourceWritesAnotherAcceptanceValue() throws {
        XCTAssertFalse(Self.forbiddenValues.contains(DeviceRunStamp.notRecorded))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let regex = try NSRegularExpression(pattern: #"deviceAcceptance\W{0,6}"(?!not_recorded")[^"]*""#)
        var offenders: [String] = []
        for directory in ["App", "Core", "Intents", "Memory", "Nexus", "Personas", "Services", "UI"] {
            let base = root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
                XCTFail("cannot enumerate \(directory)")
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    offenders.append(String(url.path.dropFirst(root.path.count + 1)))
                }
            }
        }
        XCTAssertEqual(offenders, [], "only not_recorded may be written as deviceAcceptance")
        XCTAssertNotNil(regex.firstMatch(in: #"deviceAcceptance: "accepted""#, range: NSRange(location: 0, length: 28)))
        let allowed = #"deviceAcceptance: "not_recorded""#
        XCTAssertNil(regex.firstMatch(in: allowed, range: NSRange(allowed.startIndex..., in: allowed)))
    }
}
