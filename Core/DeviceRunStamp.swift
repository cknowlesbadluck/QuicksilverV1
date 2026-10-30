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
    /// Schema of the encoded stamp. Stamps written before this field existed decode as 1.
    public let schemaVersion: Int
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
        self.schemaVersion = Self.currentSchemaVersion
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

    /// The schema this build writes and fully understands.
    public static let currentSchemaVersion = 1
    /// Clock skew allowed before a timestamp counts as "in the future".
    static let futureTolerance: TimeInterval = 5 * 60

    /// Problems that make a stamp unusable as CHR-55 evidence. An empty list does not mean
    /// acceptance: `deviceAcceptance` stays `not_recorded` either way.
    public enum ValidationIssue: String, CaseIterable, Sendable {
        case unsupportedSchema, startedInFuture, finishedInFuture, finishedBeforeStart
    }

    public func validationIssues(now: Date = Date()) -> [ValidationIssue] {
        let limit = now.addingTimeInterval(Self.futureTolerance)
        var issues: [ValidationIssue] = []
        if schemaVersion != Self.currentSchemaVersion { issues.append(.unsupportedSchema) }
        if startedAt > limit { issues.append(.startedInFuture) }
        if let finishedAt {
            if finishedAt > limit { issues.append(.finishedInFuture) }
            if finishedAt < startedAt { issues.append(.finishedBeforeStart) }
        }
        return issues
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
        case startedAt, finishedAt, results, acceptanceGate, deviceAcceptance, schemaVersion
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
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        // Values are decoded as strings so an unknown check, or a result value from a newer build,
        // is skipped instead of making the whole stamp unreadable.
        let raw = try container.decode([String: String].self, forKey: .results)
        var decoded = Dictionary(uniqueKeysWithValues: Check.allCases.map { ($0, Result.notRun) })
        for (key, value) in raw {
            if let check = Check(rawValue: key), let result = Result(rawValue: value) { decoded[check] = result }
        }
        results = decoded
        // acceptanceGate and deviceAcceptance are ignored on decode: they are constants.
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.validated(appVersion, as: .version), forKey: .appVersion)
        try container.encode(Self.validated(build, as: .version), forKey: .build)
        try container.encode(Self.validated(osVersion, as: .version), forKey: .osVersion)
        try container.encode(Self.validated(hardwareModel, as: .hardware), forKey: .hardwareModel)
        try container.encode(isSimulator, forKey: .isSimulator)
        try container.encode(Self.validated(onDeviceModel, as: .onDeviceModel), forKey: .onDeviceModel)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        let raw = Dictionary(uniqueKeysWithValues: results.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .results)
        try container.encode(Self.acceptanceGate, forKey: .acceptanceGate)
        try container.encode(Self.notRecorded, forKey: .deviceAcceptance)
    }

    /// A plain-text summary for pasting into the CHR-55 issue. Each field is checked against its
    /// real format (a version number, a `utsname` machine identifier, a known on-device model
    /// label). Anything else prints as `redacted`, so hand-edited or decoded text can't reach the
    /// summary. The format is fixed: one `key: value` per line, checks in checklist order, UTC
    /// timestamps, at most `summaryMaxLines` lines. The last line always reads
    /// `deviceAcceptance: not_recorded`. `now` only affects the validation line.
    public func redactedSummary(now: Date = Date()) -> String {
        func date(_ value: Date?) -> String {
            value.map { ISO8601DateFormatter().string(from: $0) } ?? "-"
        }
        var lines = [
            "Quicksilver device run (\(Self.acceptanceGate) evidence, not acceptance)",
            "NOT AN ACCEPTANCE CLAIM. Only the owner records \(Self.acceptanceGate).",
            "app: \(Self.validated(appVersion, as: .version)) (\(Self.validated(build, as: .version)))",
            "os: \(Self.validated(osVersion, as: .version))",
            "hardware: \(Self.validated(hardwareModel, as: .hardware))\(isSimulator ? " [simulator]" : "")",
            "onDeviceModel: \(Self.validated(onDeviceModel, as: .onDeviceModel))",
            "started: \(date(startedAt))",
            "finished: \(date(finishedAt))"
        ]
        lines += Check.allCases.map { "\($0.rawValue): \(results[$0, default: .notRun].rawValue)" }
        lines.append("allChecksPassed: \(allChecksPassed)")
        let issues = validationIssues(now: now)
        lines.append("validation: \(issues.isEmpty ? "ok" : issues.map(\.rawValue).joined(separator: ","))")
        lines.append("deviceAcceptance: \(Self.notRecorded)")
        return lines.joined(separator: "\n")
    }

    /// Exact summary line count: header, label, 4 metadata, 2 times, one per check, 3 trailers.
    public static let summaryMaxLines = 11 + Check.allCases.count

    static let redactedValue = "redacted"

    enum FieldFormat {
        case version, hardware, onDeviceModel
    }

    /// The on-device model labels a real stamp can contain (`OnDeviceModelAvailability.shortLabel`).
    static let knownOnDeviceModelLabels: Set<String> = Set(
        [OnDeviceModelAvailability.available, .deviceNotEligible, .appleIntelligenceNotEnabled,
         .modelNotReady, .unsupportedOS, .unknown("")].map(\.shortLabel)
    )

    /// Returns `value` only when it matches `format` exactly, otherwise `redacted`.
    /// `\A`/`\z` (not `^`/`$`) so a trailing newline or U+2028 can't slip through.
    /// Used by both `redactedSummary()` and `encode(to:)`, so the JSON attachment is checked too.
    static func validated(_ value: String, as format: FieldFormat) -> String {
        let pattern: String
        switch format {
        case .version: pattern = "\\A[0-9]{1,6}(\\.[0-9]{1,6}){0,3}\\z"
        case .hardware: pattern = "\\A((iPhone|iPad|iPod|Watch|RealityDevice)[0-9]{1,3},[0-9]{1,3}|arm64|x86_64|unknown)\\z"
        case .onDeviceModel:
            return knownOnDeviceModelLabels.contains(value) ? value : redactedValue
        }
        return value.range(of: pattern, options: .regularExpression) != nil ? value : redactedValue
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
