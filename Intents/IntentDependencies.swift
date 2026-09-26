import Foundation
import Core

/// Process-wide dependency registry for App Intents.
/// App Intents are system-instantiated and cannot receive constructor injection.
///
/// M1-T6: Intents talk only to `IntelligenceSurface` (MercuryBrain in production).
@MainActor
public final class IntentDependencies {
    public static let shared = IntentDependencies()

    public private(set) var surface: IntelligenceSurface?

    public var isConfigured: Bool { surface != nil }

    private init() {}

    public func configure(surface: IntelligenceSurface) {
        guard !isConfigured else { return }
        self.surface = surface
    }

    /// Resolve the configured surface or throw a cold-start-readable error.
    public func requireSurface() throws -> IntelligenceSurface {
        guard let surface else { throw AppError.nexusNotReady }
        return surface
    }

    public func resetForTesting() {
        surface = nil
    }
}
