import Foundation
import Core

/// Classifies AI / gateway failures for client retry and user messaging (M3-T5).
enum AIClientClassifier {
    /// Cap when honoring a gateway `retryAfter` (seconds).
    static let maxRetryAfterSeconds: TimeInterval = 5

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    /// Errors eligible for at most one client retry, and only before the first delta.
    static func isRetriableBeforeFirstDelta(_ error: Error) -> Bool {
        if isCancellation(error) { return false }
        if let appError = error as? AppError {
            switch appError {
            case .rateLimited, .providerUnavailable, .timedOut, .networkUnavailable:
                return true
            case .aiRateLimited:
                // Legacy direct-provider 429.
                return true
            default:
                return false
            }
        }
        if error is URLError {
            return true
        }
        return false
    }

    /// Seconds to wait before the single retry. Honors `retryAfter` when present, capped at 5 s.
    static func retryDelaySeconds(
        for error: Error,
        honorRetryAfter: Bool = true
    ) -> TimeInterval {
        guard honorRetryAfter,
              let appError = error as? AppError,
              case .rateLimited(let retryAfter) = appError,
              let retryAfter else {
            return 0
        }
        return min(max(0, retryAfter), maxRetryAfterSeconds)
    }
}
