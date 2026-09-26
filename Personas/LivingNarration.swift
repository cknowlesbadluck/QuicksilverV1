import Foundation
import Core

/// Pure living-status narration for the Sanctum / presence surface.
///
/// First person only. Never leads with an aspect name — Mercury is one being;
/// Forge / Eternal / Quicksilver are moods of the metal, not separate speakers.
public enum LivingNarration {

    public struct Reading: Sendable, Equatable {
        public let text: String
        public let insightTitle: String?
        public let nudge: (dimension: PersonalityState.Dimension, amount: Double)?

        public init(
            text: String,
            insightTitle: String? = nil,
            nudge: (dimension: PersonalityState.Dimension, amount: Double)? = nil
        ) {
            self.text = text
            self.insightTitle = insightTitle
            self.nudge = nudge
        }

        public static func == (lhs: Reading, rhs: Reading) -> Bool {
            lhs.text == rhs.text
                && lhs.insightTitle == rhs.insightTitle
                && lhs.nudge?.dimension == rhs.nudge?.dimension
                && lhs.nudge?.amount == rhs.nudge?.amount
        }
    }

    /// Default presence line before Nexus has spoken.
    public static let defaultStatus = "Mercury is here. Restless, as ever."

    /// Formats an App Intent / Shortcuts ask result. Never prefixes `[Aspect]`.
    public static func presentIntentAnswer(_ answer: String) -> String {
        answer
    }

    /// Living-status reading from Nexus-derived primitives (no Nexus import).
    public static func reading(
        insightTitle: String?,
        healthScore: Int,
        lowPowerMode: Bool
    ) -> Reading {
        if let insightTitle, !insightTitle.isEmpty {
            return Reading(text: insightTitle, insightTitle: insightTitle, nudge: nil)
        }
        if healthScore < 50 {
            return Reading(
                text: "I watch rising pressure. Health \(healthScore).",
                insightTitle: nil,
                nudge: (.skepticism, 0.04)
            )
        }
        if lowPowerMode {
            return Reading(
                text: "I note low power. Conserving.",
                insightTitle: nil,
                nudge: (.patience, 0.03)
            )
        }
        return Reading(
            text: "The Sanctum holds. I'm listening.",
            insightTitle: nil,
            nudge: nil
        )
    }
}
