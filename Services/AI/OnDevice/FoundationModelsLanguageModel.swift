import Foundation
import Core
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Factory for the real on-device model. Returns a model whose availability
/// explains why it can't answer on older OSes or SDKs, so callers never crash.
public enum SystemOnDeviceModel {
    public static func make() -> any OnDeviceLanguageModel {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return FoundationModelsLanguageModel()
        }
        #endif
        return UnsupportedOnDeviceModel()
    }
}

/// Used when the OS or SDK has no FoundationModels.
public struct UnsupportedOnDeviceModel: OnDeviceLanguageModel {
    public init() {}
    public var availability: OnDeviceModelAvailability { .unsupportedOS }
    public func respond(instructions: String?, prompt: String) async throws -> String {
        throw OnDeviceModelError.unavailable(.unsupportedOS)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
struct FoundationModelsLanguageModel: OnDeviceLanguageModel {
    var availability: OnDeviceModelAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .appleIntelligenceNotEnabled
            case .modelNotReady: return .modelNotReady
            @unknown default: return .unknown(String(describing: reason))
            }
        }
    }

    func respond(instructions: String?, prompt: String) async throws -> String {
        let session: LanguageModelSession
        if let instructions, !instructions.isEmpty {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession()
        }
        do {
            return try await session.respond(to: prompt).content
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error { throw OnDeviceModelError.contextWindowExceeded }
            if case .guardrailViolation = error { throw OnDeviceModelError.guardrailViolation }
            throw OnDeviceModelError.generationFailed(String(describing: error))
        }
    }
}
#endif
