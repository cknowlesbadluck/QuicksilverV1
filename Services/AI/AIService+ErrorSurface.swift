import Foundation
import Core

/// Hardening (phase 9): every failure that leaves `AIService` is typed. Malformed or
/// truncated wire data (gateway SSE decode errors, JSON decoding errors) becomes
/// `AppError.aiRequestFailed`, so the Brain and UI never see a raw decoder error.
extension AIService {
    nonisolated static let malformedResponseReason = "Malformed response from the intelligence route"

    nonisolated static func typedSurface(_ error: Error) -> Error {
        switch error {
        case is AppError, is CancellationError, is URLError, is OnDeviceModelError:
            return error
        case is GatewayWireDecodeError, is DecodingError:
            return AppError.aiRequestFailed(malformedResponseReason)
        default:
            return error
        }
    }
}
