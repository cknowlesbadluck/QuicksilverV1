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
            return "AI API key is not configured"
        case .aiRequestFailed:
            return "AI request failed. Please try again."
        case .unknown(let message):
            return message
        }
    }
}
