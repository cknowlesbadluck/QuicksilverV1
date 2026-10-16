import Foundation
import Core

/// Content-free diagnostics for the Codex "Export diagnostics" share sheet.
///
/// Every field is a count, a fixed enum, a Bool or a version string. There is deliberately no
/// `String` input that could carry a prompt, reply, memory text or key: credential states are
/// reported per fixed slot name, and route records contribute only their `Route` case.
public struct DiagnosticsReport: Sendable, Equatable {
    public enum CredentialSlot: String, CaseIterable, Sendable {
        case gatewayURL = "Gateway URL"
        case gatewayToken = "Gateway token"
        case grokKey = "Grok key"
        case geminiKey = "Gemini key"
    }

    public var appVersion: String
    public var build: String
    public var routeCounts: [RouteRecord.Route: Int]
    public var budgetRemaining: Int?
    public var budgetLimit: Int?
    public var credentials: [CredentialSlot: KeychainStore.CredentialState]
    public var memoryTotal: Int
    public var memoryNotes: Int
    public var memoryUsingBackupStore: Bool
    public var onDeviceAvailable: Bool

    public init(
        appVersion: String, build: String, routes: [RouteRecord], budget: CloudBudget?,
        credentials: [CredentialSlot: KeychainStore.CredentialState],
        memoryTotal: Int, memoryNotes: Int, memoryUsingBackupStore: Bool, onDeviceAvailable: Bool
    ) {
        self.appVersion = Self.versionSafe(appVersion)
        self.build = Self.versionSafe(build)
        self.routeCounts = Dictionary(routes.map { ($0.route, 1) }, uniquingKeysWith: +)
        self.budgetRemaining = budget?.remaining
        self.budgetLimit = budget?.limit
        self.credentials = credentials
        self.memoryTotal = memoryTotal
        self.memoryNotes = memoryNotes
        self.memoryUsingBackupStore = memoryUsingBackupStore
        self.onDeviceAvailable = onDeviceAvailable
    }

    /// Keeps only version-like characters, so a corrupted Info.plist value can't carry text.
    static func versionSafe(_ raw: String) -> String {
        let kept = raw.filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == "-") }
        return kept.isEmpty ? "unknown" : String(kept.prefix(24))
    }

    static func describe(_ state: KeychainStore.CredentialState) -> String {
        switch state {
        case .present: return "present"
        case .missing: return "missing"
        case .locked: return "locked"
        case .unreadable(let status): return "unreadable (\(status))"
        }
    }

    public var text: String {
        var lines = ["Quicksilver diagnostics (no prompts, replies, notes or keys)"]
        lines.append("Version: \(appVersion) (\(build))")
        lines.append("On-device model: \(onDeviceAvailable ? "available" : "unavailable")")
        let order: [RouteRecord.Route] = [.onDevice, .memoryRecall, .cloudMinimal, .cloudStandard, .keptOnDevice, .budgetSpent, .failed]
        let routes = order.map { "\($0.rawValue)=\(routeCounts[$0, default: 0])" }.joined(separator: " ")
        lines.append("Recent routes: \(routes)")
        if let remaining = budgetRemaining, let limit = budgetLimit {
            lines.append("Cloud budget: \(remaining)/\(limit)")
        } else {
            lines.append("Cloud budget: not reported")
        }
        for slot in CredentialSlot.allCases {
            lines.append("Keychain \(slot.rawValue): \(credentials[slot].map(Self.describe) ?? "missing")")
        }
        lines.append("Memory: \(memoryTotal) items, \(memoryNotes) notes, store=\(memoryUsingBackupStore ? "backup" : "primary")")
        lines.append(
            "Privacy gate: floor=remote may tighten, never loosen; phrases=\(CloudContextPolicy.personalPhrases.count) "
                + "words=\(CloudContextPolicy.personalWords.count); non-English fails closed at "
                + "\(CloudContextPolicy.nonEnglishConfidence) (min \(CloudContextPolicy.languageMinimumLetters) letters)"
        )
        return lines.joined(separator: "\n")
    }
}

extension AIService {
    /// Keychain state per fixed slot (never values).
    public func credentialStates() -> [DiagnosticsReport.CredentialSlot: KeychainStore.CredentialState] {
        let accounts: [DiagnosticsReport.CredentialSlot: String] = [
            .gatewayURL: Self.gatewayBaseURLKeychainAccount, .gatewayToken: GatewayAIProvider.deviceTokenKeychainAccount,
            .grokKey: Self.grokAPIKeyKeychainAccount, .geminiKey: Self.geminiAPIKeyKeychainAccount
        ]
        return accounts.mapValues { KeychainStore.credentialState(forKey: $0) }
    }
}
