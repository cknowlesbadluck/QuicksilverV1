import Foundation

/// CHR-55 scaffolding: a content-free record of one owner device run, for attaching to the
/// device-acceptance issue. It holds only build, OS, hardware identifier, on-device model state,
/// timestamps and the pass, fail or not-run result of each fixed checklist step. It never holds
/// notes, turns, prompts or any user text.
///
/// This type cannot claim acceptance. `deviceAcceptance` is always `not_recorded`, even when every
/// step passed and even if a decoded payload says otherwise. Only the owner records CHR-55, outside
/// the app.
public struct DeviceRunStamp: Codable, Equatable, Sendable {
    /// The owner device checklist (docs/QUICKSILVER-ROADMAP-1.0.md, Phase 1), in order.
    public enum Check: String, Codable, CaseIterable, Sendable {
        case sideStoreInstall
        case coldLaunch
        case onDeviceAnswer
        case keychainAfterReboot
        case spotlightTap
        case voiceOver
        case memoryAtCap
    }

    public enum Result: String, Codable, Sendable {
        case notRun
        case passed
        case failed
    }

    public static let acceptanceGate = "CHR-55"
    public static let notRecorded = "not_recorded"

    public let appVersion: String
    public let build: String
    public let osVersion: String
    /// Hardware identifier such as "iPhone17,5", never the user-assigned device name.
    public let hardwareModel: String
    public let isSimulator: Bool
    /// `OnDeviceModelAvailability.shortLabel`, a fixed vocabulary.
    public let onDeviceModel: String
    public let startedAt: Date
    public private(set) var finishedAt: Date?
    public private(set) var results: [Check: Result]

    /// Always `not_recorded`; see the type comment.
    public var deviceAcceptance: String { Self.notRecorded }

    public init(
        configuration: AppConfiguration,
        osVersion: String,
        hardwareModel: String,
        isSimulator: Bool,
        onDeviceModel: OnDeviceModelAvailability,
        startedAt: Date
    ) {
        appVersion = configuration.version
        build = configuration.build
        self.osVersion = osVersion
        self.hardwareModel = hardwareModel
        self.isSimulator = isSimulator
        self.onDeviceModel = onDeviceModel.shortLabel
        self.startedAt = startedAt
        finishedAt = nil
        results = Dictionary(uniqueKeysWithValues: Check.allCases.map { ($0, .notRun) })
    }

    /// The stamp for the running process.
    public static func current(
        onDeviceModel: OnDeviceModelAvailability,
        configuration: AppConfiguration = .shared,
        now: Date = Date()
    ) -> DeviceRunStamp {
        #if targetEnvironment(simulator)
        let simulator = true
        #else
        let simulator = false
        #endif
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return DeviceRunStamp(
            configuration: configuration,
            osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            hardwareModel: hardwareIdentifier(),
            isSimulator: simulator,
            onDeviceModel: onDeviceModel,
            startedAt: now
        )
    }

    public mutating func record(_ check: Check, _ result: Result) {
        results[check] = result
    }

    public mutating func finish(at date: Date) {
        finishedAt = date
    }

    /// True when every step passed on real hardware. This is evidence for the owner to review,
    /// not acceptance: `deviceAcceptance` stays `not_recorded`.
    public var allChecksPassed: Bool {
        !isSimulator && Check.allCases.allSatisfy { results[$0] == .passed }
    }

    /// Stable, sorted JSON for attaching to the issue.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case appVersion, build, osVersion, hardwareModel, isSimulator, onDeviceModel
        case startedAt, finishedAt, results, acceptanceGate, deviceAcceptance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        build = try container.decode(String.self, forKey: .build)
        osVersion = try container.decode(String.self, forKey: .osVersion)
        hardwareModel = try container.decode(String.self, forKey: .hardwareModel)
        isSimulator = try container.decode(Bool.self, forKey: .isSimulator)
        onDeviceModel = try container.decode(String.self, forKey: .onDeviceModel)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        let raw = try container.decode([String: Result].self, forKey: .results)
        var decoded = Dictionary(uniqueKeysWithValues: Check.allCases.map { ($0, Result.notRun) })
        for (key, value) in raw {
            if let check = Check(rawValue: key) { decoded[check] = value }
        }
        results = decoded
        // acceptanceGate and deviceAcceptance are ignored on decode: they are constants.
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(build, forKey: .build)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(hardwareModel, forKey: .hardwareModel)
        try container.encode(isSimulator, forKey: .isSimulator)
        try container.encode(onDeviceModel, forKey: .onDeviceModel)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
        let raw = Dictionary(uniqueKeysWithValues: results.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .results)
        try container.encode(Self.acceptanceGate, forKey: .acceptanceGate)
        try container.encode(Self.notRecorded, forKey: .deviceAcceptance)
    }

    /// A plain-text summary for pasting into the CHR-55 issue. It is built only from the stamp's
    /// fixed fields, with every free-form field passed through `redacted(_:)`, so it can't carry
    /// user content. The last line always reads `deviceAcceptance: not_recorded`.
    public func redactedSummary() -> String {
        func date(_ value: Date?) -> String {
            value.map { ISO8601DateFormatter().string(from: $0) } ?? "-"
        }
        var lines = [
            "Quicksilver device run (\(Self.acceptanceGate) evidence, not acceptance)",
            "app: \(Self.redacted(appVersion)) (\(Self.redacted(build)))",
            "os: \(Self.redacted(osVersion))",
            "hardware: \(Self.redacted(hardwareModel))\(isSimulator ? " [simulator]" : "")",
            "onDeviceModel: \(Self.redacted(onDeviceModel))",
            "started: \(date(startedAt))",
            "finished: \(date(finishedAt))"
        ]
        lines += Check.allCases.map { "\($0.rawValue): \(results[$0, default: .notRun].rawValue)" }
        lines.append("allChecksPassed: \(allChecksPassed)")
        lines.append("deviceAcceptance: \(Self.notRecorded)")
        return lines.joined(separator: "\n")
    }

    /// Keeps only `[A-Za-z0-9 .,()_-]`, at most 32 characters, so a decoded or hand-edited field
    /// can't smuggle free text into the summary.
    static func redacted(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,()_-")
        let kept = String(value.filter { allowed.contains($0) }.prefix(32))
        return kept.isEmpty ? "-" : kept
    }

    /// `utsname.machine`, e.g. "iPhone17,5". On the simulator this is the host architecture.
    private static func hardwareIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(bytes: buffer.prefix { $0 != 0 }, encoding: .utf8) ?? "unknown"
        }
    }
}
