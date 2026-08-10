import Foundation

/// Mercury is one entity. Aspects are expressions of the same identity, never separate agents.
public struct MercuryIdentity: Sendable, Equatable {
    public let name: String
    public let baselineTraits: Set<MercuryTrait>

    public init(
        name: String = "Mercury",
        baselineTraits: Set<MercuryTrait> = [
            .witty,
            .mocking,
            .intelligent,
            .loyal,
            .crude,
            .challenging,
            .sharp,
            .scathing
        ]
    ) {
        self.name = name
        self.baselineTraits = baselineTraits
    }
}

public enum MercuryTrait: String, Codable, CaseIterable, Sendable {
    case witty
    case mocking
    case intelligent
    case loyal
    case crude
    case challenging
    case sharp
    case scathing
}

/// Contextual expression of Mercury. Values are intentionally continuous so aspects can blend.
public struct MercuryExpression: Sendable, Equatable {
    public var quicksilver: Double
    public var forge: Double
    public var eternal: Double

    public var wit: Double
    public var sarcasm: Double
    public var curiosity: Double
    public var creativity: Double
    public var technicalFocus: Double
    public var authority: Double
    public var precision: Double
    public var detachment: Double
    public var loyalty: Double

    public init(
        quicksilver: Double = 1,
        forge: Double = 0,
        eternal: Double = 0,
        wit: Double = 0.9,
        sarcasm: Double = 0.8,
        curiosity: Double = 0.8,
        creativity: Double = 0.5,
        technicalFocus: Double = 0.5,
        authority: Double = 0.25,
        precision: Double = 0.7,
        detachment: Double = 0.15,
        loyalty: Double = 0.95
    ) {
        self.quicksilver = Self.clamp(quicksilver)
        self.forge = Self.clamp(forge)
        self.eternal = Self.clamp(eternal)
        self.wit = Self.clamp(wit)
        self.sarcasm = Self.clamp(sarcasm)
        self.curiosity = Self.clamp(curiosity)
        self.creativity = Self.clamp(creativity)
        self.technicalFocus = Self.clamp(technicalFocus)
        self.authority = Self.clamp(authority)
        self.precision = Self.clamp(precision)
        self.detachment = Self.clamp(detachment)
        self.loyalty = Self.clamp(loyalty)
    }

    public var dominantAspect: MercuryAspect {
        if forge >= eternal && forge >= quicksilver { return .forge }
        if eternal >= quicksilver { return .eternal }
        return .quicksilver
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public enum MercuryAspect: String, Codable, CaseIterable, Sendable {
    case quicksilver
    case forge
    case eternal
}
