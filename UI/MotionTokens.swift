import SwiftUI

/// Named motion presets for Mercury.
/// Every animation in the app should reference one of these.
/// No anonymous springs or durations scattered through views.
enum MotionTokens {

    // MARK: - Ambient (always present)

    /// Slow core breathing — idle life.
    static let mercuryBreath = Animation.easeInOut(duration: 3.2).repeatForever(autoreverses: true)

    /// Distant celestial / glyph orbit.
    static let celestialOrbit = Animation.linear(duration: 48).repeatForever(autoreverses: false)

    /// Faster internal fluid when thinking.
    static let thinkingCirculation = Animation.easeInOut(duration: 1.15).repeatForever(autoreverses: true)

    // MARK: - Interaction

    static let glyphActivation = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let energyPulse = Animation.spring(response: 0.36, dampingFraction: 0.68)
    static let instrumentReveal = Animation.spring(response: 0.48, dampingFraction: 0.78)
    static let invocationExpand = Animation.spring(response: 0.42, dampingFraction: 0.80)
    static let invocationCollapse = Animation.spring(response: 0.38, dampingFraction: 0.86)

    // MARK: - State

    static let environmentalWake = Animation.easeOut(duration: 0.9)
    static let stabilization = Animation.spring(response: 0.55, dampingFraction: 0.88)
    static let warningPulse = Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)

    // MARK: - Transition

    /// Spatial realm change — longer, deliberate.
    static let realmTransition = Animation.spring(response: 0.72, dampingFraction: 0.84)

    // MARK: - Persona-tinted springs (compat with existing call sites)

    static func spring(for personaID: String) -> Animation {
        switch personaID.lowercased() {
        case "forge":
            return .spring(response: 0.30, dampingFraction: 0.84) // forgeMechanism
        case "eternal":
            return .spring(response: 0.55, dampingFraction: 0.78)
        default:
            return .spring(response: 0.40, dampingFraction: 0.76)
        }
    }

    // MARK: - Reduce Motion fallbacks

    /// When Reduce Motion is on, prefer cross-fade over spatial movement.
    static func reduced(_ preferred: Animation) -> Animation {
        .easeInOut(duration: 0.25)
    }
}
