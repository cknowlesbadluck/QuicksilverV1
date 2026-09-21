import Foundation

/// A structured capability the intelligence surface can invoke.
/// Replaces ad-hoc Brain methods (remember / retrieve / correct) with
/// explicit, policy-gated tools. Pure description — execution lives elsewhere.
public struct Capability: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let kind: Kind
    public let requiresUserInitiation: Bool

    public init(
        id: String,
        name: String,
        kind: Kind,
        requiresUserInitiation: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.requiresUserInitiation = requiresUserInitiation
    }

    public enum Kind: String, Sendable, Equatable, CaseIterable {
        case memoryWrite
        case memoryRead
        case memoryCorrect
        case express
        case diagnose
        case plan
        case invokeTool
    }

    // MARK: - Canonical set (extensible later)

    public static let remember = Capability(
        id: "capability.remember",
        name: "Remember",
        kind: .memoryWrite
    )

    public static let retrieve = Capability(
        id: "capability.retrieve",
        name: "Retrieve",
        kind: .memoryRead
    )

    public static let correct = Capability(
        id: "capability.correct",
        name: "Correct",
        kind: .memoryCorrect
    )

    public static let express = Capability(
        id: "capability.express",
        name: "Express",
        kind: .express
    )

    public static let diagnose = Capability(
        id: "capability.diagnose",
        name: "Diagnose",
        kind: .diagnose,
        requiresUserInitiation: false
    )
}
