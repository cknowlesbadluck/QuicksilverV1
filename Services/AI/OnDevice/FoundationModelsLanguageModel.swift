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
    /// One warmed, unused session for the next request (single-use; see PrewarmedSessionCache).
    private let warm = PrewarmedSessionCache<LanguageModelSession>()

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

    func prewarm(instructions: String?) {
        guard availability.isAvailable else { return }
        let session = Self.session(instructions: instructions)
        session.prewarm()
        warm.store(session, for: instructions)
    }

    func discardPrewarmed() { warm.discard() }

    private static func session(instructions: String?) -> LanguageModelSession {
        if let instructions, !instructions.isEmpty {
            return LanguageModelSession(instructions: instructions)
        }
        return LanguageModelSession()
    }

    func respond(instructions: String?, prompt: String) async throws -> String {
        // Reuse the warmed session only if it was built for these exact instructions.
        let session = warm.take(for: instructions) ?? Self.session(instructions: instructions)
        defer { prewarm(instructions: instructions) } // warm a fresh one for the next turn
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
