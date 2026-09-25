import Foundation

/// Typed error surface for Quicksilver.
/// Prevents stringly-typed errors and enables structured logging / user messaging later.
public enum AppError: Error, LocalizedError, Sendable {
    case configurationMissing(String)
    case personaUnavailable(String)
    case nexusNotReady
    case networkUnavailable
    case unsupportedFeature(String)
    case apiKeyMissing
    /// Intelligence is switched off in the Codex (`aiServiceEnabled == false`).
    case intelligenceDisabled
    case aiRequestFailed(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .configurationMissing(let key):
            return "Missing configuration: \(key)"
        case .personaUnavailable(let id):
            return "Persona unavailable: \(id)"
        case .nexusNotReady:
            return "Nexus subsystem is not ready"
        case .networkUnavailable:
            return "Network is currently unavailable"
        case .unsupportedFeature(let name):
            return "Feature not yet supported: \(name)"
        case .apiKeyMissing:
            return Self.unboundNotice
        case .intelligenceDisabled:
            return Self.dormantNotice
        case .aiRequestFailed:
            return "AI request failed. Please try again."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Intelligence unbound (M1-T3)

extension AppError {
    /// Short in-character notice shown when no real provider is bound. Never fabricated model text.
    public static let unboundNotice = "Intelligence unbound — bind a key in the Codex."
    /// Shown when a key may be bound but intelligence is switched off in the Codex.
    public static let dormantNotice = "Intelligence unbound — wake it in the Codex."

    /// True when the error means "no intelligence is bound or enabled", as opposed to a failed request.
    public var isIntelligenceUnbound: Bool {
        switch self {
        case .apiKeyMissing, .intelligenceDisabled:
            return true
        default:
            return false
        }
    }

    /// The unbound notice for `error`, or `nil` when the error is not an unbound state.
    public static func unboundNotice(for error: Error) -> String? {
        guard let appError = error as? AppError, appError.isIntelligenceUnbound else { return nil }
        return appError.errorDescription
    }
}
