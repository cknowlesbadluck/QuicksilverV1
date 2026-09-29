import Foundation
import Core

/// Maps a non-2xx provider status onto a distinguishable `AppError`.
/// 401/403 (bad or revoked key) and 429 (rate limit) need different user actions,
/// so they map to distinct `AppError` cases whose `errorDescription` tells the user what to do.
enum ProviderHTTPError {
    static func error(provider: String, status: Int) -> AppError {
        switch status {
        case 401, 403:
            return .aiKeyRejected(provider: provider)
        case 429:
            return .aiRateLimited(provider: provider)
        default:
            return .aiRequestFailed("\(provider) API request failed (HTTP \(status))")
        }
    }
}
