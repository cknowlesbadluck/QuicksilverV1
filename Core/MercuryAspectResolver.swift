import Foundation

public struct MercuryContextSignals: Sendable, Equatable {
    public let creativeIntensity: Double
    public let technicalIntensity: Double
    public let codexRelevance: Double
    public let automationRelevance: Double
    public let conversationalIntensity: Double

    public init(
        creativeIntensity: Double = 0,
        technicalIntensity: Double = 0,
        codexRelevance: Double = 0,
        automationRelevance: Double = 0,
        conversationalIntensity: Double = 0
    ) {
        self.creativeIntensity = Self.clamp(creativeIntensity)
        self.technicalIntensity = Self.clamp(technicalIntensity)
        self.codexRelevance = Self.clamp(codexRelevance)
        self.automationRelevance = Self.clamp(automationRelevance)
        self.conversationalIntensity = Self.clamp(conversationalIntensity)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// Resolves expression from context without changing Mercury's identity.
public struct MercuryAspectResolver: Sendable {
    public init() {}

    public func resolve(_ signals: MercuryContextSignals) -> MercuryExpression {
        let forge = min(1, (signals.creativeIntensity * 0.65) + (signals.technicalIntensity * 0.35))
        let eternal = min(1, (signals.codexRelevance * 0.55) + (signals.automationRelevance * 0.45))
        let quicksilver = max(0.15, 1 - max(forge, eternal) * 0.7)

        let curiosity = min(1, 0.65 + signals.creativeIntensity * 0.25 + signals.technicalIntensity * 0.10)
        let creativity = min(1, 0.40 + signals.creativeIntensity * 0.60)
        let technicalFocus = min(1, 0.45 + signals.technicalIntensity * 0.55)
        let precision = min(1, 0.65 + eternal * 0.30 + signals.technicalIntensity * 0.05)
        let authority = min(1, 0.20 + eternal * 0.65)
        let detachment = min(1, 0.10 + eternal * 0.50)
        let wit = min(1, 0.82 + signals.conversationalIntensity * 0.12)
        let sarcasm = min(1, 0.72 + signals.conversationalIntensity * 0.20)

        return MercuryExpression(
            quicksilver: quicksilver,
            forge: forge,
            eternal: eternal,
            wit: wit,
            sarcasm: sarcasm,
            curiosity: curiosity,
            creativity: creativity,
            technicalFocus: technicalFocus,
            authority: authority,
            precision: precision,
            detachment: detachment,
            loyalty: 0.95
        )
    }
}
