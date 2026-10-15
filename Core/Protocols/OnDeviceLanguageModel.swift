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

    /// Short state for the Codex "Mind" section (M3.5-T5).
    public var shortLabel: String {
        switch self {
        case .available: return "Available"
        case .deviceNotEligible: return "Not eligible"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence off"
        case .modelNotReady: return "Preparing model"
        case .unsupportedOS: return "Requires iOS 26"
        case .unknown: return "Unavailable"
        }
    }

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
    /// Drops any warmed session (memory pressure, AI switched off). Best effort.
    func discardPrewarmed()
}

extension OnDeviceLanguageModel {
    public func prewarm(instructions: String?) {}
    public func discardPrewarmed() {}
}

/// Typed failures from the on-device model (M3.5-T2), mapped from framework errors.
public enum OnDeviceModelError: Error, Equatable, Sendable {
    case unavailable(OnDeviceModelAvailability)
    case contextWindowExceeded
    case guardrailViolation
    case generationFailed(String)
}
