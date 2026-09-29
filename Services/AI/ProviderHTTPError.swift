import Foundation
import Core

/// Maps a non-2xx provider status onto a distinguishable `AppError`.
/// 401/403 (bad or revoked key) and 429 (rate limit) need different user actions,
/// so they carry distinct reasons instead of one generic "request failed".
enum ProviderHTTPError {
    static func error(provider: String, status: Int) -> AppError {
        switch status {
        case 401, 403:
            return .aiRequestFailed("\(provider) rejected the API key (HTTP \(status)). Rebind the key in the Codex.")
        case 429:
            return .aiRequestFailed("\(provider) rate limit reached (HTTP 429). Try again shortly.")
        default:
            return .aiRequestFailed("\(provider) API request failed (HTTP \(status))")
        }
    }
}
