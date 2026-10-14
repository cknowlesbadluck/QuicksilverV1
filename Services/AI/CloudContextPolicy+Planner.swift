import Foundation
import Core

/// M3.5-T19: local, deterministic `needsCloud` planner.
///
/// Only a clearly impersonal knowledge or task question is eligible for the cloud.
/// Everything else stays on device. No model, no network: pure text rules, so the
/// same input always yields the same plan. Lives with CloudContextPolicy, the
/// single privacy checkpoint.
public enum CloudPlan: Equatable, Sendable {
    case cloudEligible
    case localOnly(reason: String)

    public var isCloudEligible: Bool { self == .cloudEligible }
}

extension CloudContextPolicy {
    /// Plan for one turn. Personal turns, first-person turns and non-knowledge turns stay local.
    public static func plan(_ request: AIRequest) -> CloudPlan {
        if isPersonal(request) { return .localOnly(reason: "personal") }
        let tokens = tokenized(RegisterPolicy.normalize(request.prompt)).split(separator: " ").map(String.init)
        guard let first = tokens.first else { return .localOnly(reason: "empty") }
        if tokens.contains(where: firstPersonTokens.contains) { return .localOnly(reason: "first-person") }
        guard knowledgeCues.contains(first) else { return .localOnly(reason: "not a knowledge question") }
        return .cloudEligible
    }

    /// Owner-referencing words. A turn about the owner is never a pure knowledge question.
    static let firstPersonTokens: Set<String> = [
        "i", "i'm", "im", "i've", "i'd", "i'll", "me", "my", "mine", "myself",
        "we", "we're", "our", "ours", "us", "ourselves"
    ]

    /// Leading words of knowledge questions and impersonal tasks.
    static let knowledgeCues: Set<String> = [
        "what", "what's", "whats", "who", "who's", "when", "where", "why", "how", "which",
        "is", "are", "does", "do", "can", "could", "explain", "define", "describe", "summarize",
        "summarise", "translate", "compare", "list", "calculate", "convert", "write", "draft",
        "plan", "suggest", "give", "tell", "outline", "name"
    ]
}
