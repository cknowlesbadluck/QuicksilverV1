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
    /// The provider rejected the bound API key (HTTP 401/403). The user must rebind it.
    /// Legacy direct Grok/Gemini path; gateway uses `.unauthorized` (no provider name).
    case aiKeyRejected(provider: String)
    /// The provider is rate limiting requests (HTTP 429). Retrying later can succeed.
    /// Legacy direct Grok/Gemini path; gateway uses `.rateLimited(retryAfter:)` (no provider name).
    case aiRateLimited(provider: String)

    // MARK: Gateway / classified client errors (M3-T5)
    // User-facing text must not name a provider.

    /// HTTP 429 / wire `rate_limited`. `retryAfter` is seconds when the gateway supplied it.
    case rateLimited(retryAfter: TimeInterval?)
    /// HTTP 401/403 / wire `unauthorized`.
    case unauthorized
    /// HTTP 5xx / wire `upstream_unavailable`.
    case providerUnavailable
    /// Wire `budget_exhausted` — daily free-tier budget spent.
    case budgetExhausted
    /// Connect / first-event / idle / total timeout, or wire `timeout`.
    case timedOut

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
        case .aiKeyRejected(let provider):
            return "\(provider) rejected the API key. Rebind it in the Codex."
        case .aiRateLimited(let provider):
            return "\(provider) is rate limiting requests. Try again in a moment."
        case .rateLimited:
            return "Too many requests. Try again in a moment."
        case .unauthorized:
            return "Authorization failed. Rebind credentials in the Codex."
        case .providerUnavailable:
            return "Intelligence is temporarily unavailable. Try again shortly."
        case .budgetExhausted:
            return "Daily intelligence budget is exhausted. Try again tomorrow."
        case .timedOut:
            return "The request timed out. Please try again."
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
