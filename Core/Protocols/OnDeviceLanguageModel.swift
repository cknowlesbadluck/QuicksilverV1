import Foundation

/// M3.5-T1: why the on-device model can or cannot answer. Mirrors Apple's
/// `SystemLanguageModel.Availability` without importing FoundationModels in Core.
public enum OnDeviceModelAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedOS
    case unknown(String)

    public var isAvailable: Bool { self == .available }

    /// Plain explanation for the Codex (shown when Apple Intelligence can't answer).
    public var userFacingReason: String {
        switch self {
        case .available: return "On-device mind is ready."
        case .deviceNotEligible: return "This device can't run Apple Intelligence."
        case .appleIntelligenceNotEnabled: return "Turn on Apple Intelligence in Settings to use the on-device mind."
        case .modelNotReady: return "The on-device model is still downloading or preparing."
        case .unsupportedOS: return "The on-device mind needs iOS 26 or later."
        case .unknown(let detail): return "On-device mind unavailable (\(detail))."
        }
    }
}

/// Seam over an on-device language model session. The real implementation wraps
/// FoundationModels; tests use a fake. Text in, text out; nothing leaves the device.
public protocol OnDeviceLanguageModel: Sendable {
    var availability: OnDeviceModelAvailability { get }
    func respond(instructions: String?, prompt: String) async throws -> String
    /// M3.5-T4: load the model ahead of the first request. Best effort.
    func prewarm(instructions: String?)
}

extension OnDeviceLanguageModel {
    public func prewarm(instructions: String?) {}
}

/// Typed failures from the on-device model (M3.5-T2), mapped from framework errors.
public enum OnDeviceModelError: Error, Equatable, Sendable {
    case unavailable(OnDeviceModelAvailability)
    case contextWindowExceeded
    case guardrailViolation
    case generationFailed(String)
}
