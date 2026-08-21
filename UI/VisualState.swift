import Foundation

/// Explicit visual communication states for Mercury.
/// The environment, Quicksilver core, glyphs, and instruments react to these.
/// Never driven by local UI heuristics — Brain / Nexus own the truth.
public enum VisualState: String, Sendable, Equatable, CaseIterable {
    case idle
    case listening
    case thinking
    case speaking
    case processing
    case success
    case warning
    case critical
    case transitioning
    case sleeping

    /// Compatibility state for legacy realm surfaces.
    /// Maps the former generic elevated state to the semantic processing state.
    public static var elevated: Self { .processing }

    /// Relative energy of the environment (0...1).
    public var ambientEnergy: Double {
        switch self {
        case .idle: return 0.28
        case .listening: return 0.42
        case .thinking: return 0.62
        case .speaking: return 0.55
        case .processing: return 0.78
        case .success: return 0.38
        case .warning: return 0.70
        case .critical: return 0.92
        case .transitioning: return 0.65
        case .sleeping: return 0.08
        }
    }

    /// Core brightness multiplier.
    public var coreBrightness: Double {
        switch self {
        case .idle: return 0.75
        case .listening: return 0.95
        case .thinking: return 1.10
        case .speaking: return 1.05
        case .processing: return 1.20
        case .success: return 0.90
        case .warning: return 1.05
        case .critical: return 1.25
        case .transitioning: return 1.00
        case .sleeping: return 0.35
        }
    }

    /// Particle density multiplier relative to chamber baseline.
    public var particleMultiplier: Double {
        switch self {
        case .idle: return 0.7
        case .listening: return 0.9
        case .thinking: return 1.35
        case .speaking: return 1.1
        case .processing: return 1.6
        case .success: return 0.85
        case .warning: return 1.4
        case .critical: return 1.8
        case .transitioning: return 1.2
        case .sleeping: return 0.25
        }
    }

    public var isElevated: Bool {
        switch self {
        case .thinking, .processing, .warning, .critical, .transitioning:
            return true
        default:
            return false
        }
    }
}
