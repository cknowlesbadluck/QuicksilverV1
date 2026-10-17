import SwiftUI

/// Named motion presets for Mercury.
/// Every animation in the app should reference one of these.
/// No anonymous springs or durations scattered through views.
enum MotionTokens {

    // MARK: - Durations (raw intervals; prefer Animation presets below)

    /// Living-core pulse period (MercuryPresenceOrb TimelineView phase).
    static let corePulseDuration: TimeInterval = 2.8
    /// Legacy timed realm cross-fade (spring `realmTransition` is preferred).
    static let realmTransitionDuration: TimeInterval = 0.42
    /// Short press / pill micro-interaction.
    static let microInteractionDuration: TimeInterval = 0.16

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

    // MARK: - Ambient cadence (energy-aware)

    /// Full-life decorative frame interval (30 fps).
    static let ambientFrameInterval: TimeInterval = 1.0 / 30.0
    /// Slower decorative layers (chaos field).
    static let ambientSlowFrameInterval: TimeInterval = 1.0 / 24.0
    /// Reduce Motion fallback for layers that keep a trickle of life (8 fps).
    static let reducedFrameInterval: TimeInterval = 1.0 / 8.0
    /// Ceiling while the device conserves energy (Low Power Mode, serious thermal): 10 fps.
    static let conservingFrameInterval: TimeInterval = 1.0 / 10.0

    /// Frame interval for a decorative TimelineView. Never faster than `preferred`; while the
    /// device conserves energy, never faster than `conservingFrameInterval`.
    static func ambientInterval(_ preferred: TimeInterval, energy: AmbientEnergy) -> TimeInterval {
        energy.isConserving ? max(preferred, conservingFrameInterval) : preferred
    }

    /// Decorative time stops entirely under critical thermal pressure.
    static func ambientPaused(_ energy: AmbientEnergy) -> Bool {
        energy.thermal == .critical
    }

    // MARK: - Reduce Motion fallbacks

    /// When Reduce Motion is on, prefer a short cross-fade over spatial or repeating motion.
    /// Repeat-forever presets must not survive this path.
    static func reduced(_ preferred: Animation) -> Animation {
        .easeInOut(duration: 0.25)
    }

    /// Single policy for every call site. Reduced motion always wins over orbit, breath, and springs.
    static func resolved(_ preferred: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced(preferred) : preferred
    }
}
