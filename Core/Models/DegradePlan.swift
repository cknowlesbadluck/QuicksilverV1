import Foundation

/// Maps a host probe or gateway error into one on-device action.
/// Fail closed. Setting names may be classified. Values never are.
public enum HostClass: String, Codable, Sendable, Equatable {
    case ready
    case ownerGate = "owner_gate"
    case aliasAbsent = "alias_absent"
    case authRequired = "auth_required"
    case rateLimited = "rate_limited"
    case budgetExhausted = "budget_exhausted"
    case unknown
}

public enum DegradeAction: String, Codable, Sendable, Equatable {
    case proceed
    case askOwner = "ask_owner"
    case ignoreAlias = "ignore_alias"
    case reauth
    case backoff
    case stayLocal = "stay_local"
}

public struct DegradePlan: Codable, Sendable, Equatable {
    public let host: HostClass
    public let action: DegradeAction
    public let retryable: Bool
    public let missingNames: [String]

    public init(host: HostClass, action: DegradeAction, retryable: Bool, missingNames: [String]) {
        self.host = host
        self.action = action
        self.retryable = retryable
        self.missingNames = missingNames
    }
}

public struct HostProbe: Sendable, Equatable {
    public let status: Int
    public let code: String
    public let missingRequired: [String]
    public let bodyText: String

    public init(status: Int, code: String = "", missingRequired: [String] = [], bodyText: String = "") {
        self.status = status
        self.code = code
        self.missingRequired = missingRequired
        self.bodyText = bodyText
    }
}

public enum DegradePlanner {
    private static let name = try! NSRegularExpression(pattern: "^[A-Z][A-Z0-9_]{2,64}$")

    public static func plan(_ probe: HostProbe) -> DegradePlan {
        let missingNames = probe.missingRequired.filter(isSettingName)
        if probe.code == "budget_exhausted" || probe.code == "budgetExhausted" {
            return DegradePlan(host: .budgetExhausted, action: .stayLocal, retryable: false, missingNames: missingNames)
        }
        if probe.code == "rate_limited" || probe.code == "rateLimited" || probe.status == 429 {
            return DegradePlan(host: .rateLimited, action: .backoff, retryable: true, missingNames: missingNames)
        }
        if probe.code == "unauthorized" || probe.status == 401 || probe.status == 403 {
            return DegradePlan(host: .authRequired, action: .reauth, retryable: false, missingNames: missingNames)
        }
        if probe.status == 404 && probe.bodyText.contains("DEPLOYMENT_NOT_FOUND") {
            return DegradePlan(host: .aliasAbsent, action: .ignoreAlias, retryable: false, missingNames: [])
        }
        if probe.status == 503 && !missingNames.isEmpty {
            return DegradePlan(host: .ownerGate, action: .askOwner, retryable: false, missingNames: missingNames)
        }
        if probe.status == 200 && (probe.code.isEmpty || probe.code == "ok" || probe.code == "ready") {
            return DegradePlan(host: .ready, action: .proceed, retryable: false, missingNames: [])
        }
        return DegradePlan(host: .unknown, action: .stayLocal, retryable: false, missingNames: [])
    }

    private static func isSettingName(_ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard name.firstMatch(in: value, range: range) != nil else { return false }
        let lowered = value.lowercased()
        return !lowered.contains("postgres:") && !lowered.contains("eyj") && !lowered.contains("api_key") && !lowered.contains("api-key")
    }
}
