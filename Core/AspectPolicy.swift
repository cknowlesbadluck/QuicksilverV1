import Foundation

/// Selects the active Aspect of the single Quicksilver entity.
/// Pure and side-effect free. Consumes Core.Intent + lightweight context.
///
/// Priority: strong Intent signal → continuity / environmental fallbacks.
/// Does not own persona switching; callers (MercuryBrain) map Aspect →
/// existing PersonaConfiguration during the transition period.
public struct AspectPolicy: Sendable {

    /// Lightweight environment for turn-time aspect selection (P-T18).
    public struct Environment: Sendable, Equatable {
        public var isLowPower: Bool
        public var thermalState: String?

        public init(isLowPower: Bool = false, thermalState: String? = nil) {
            self.isLowPower = isLowPower
            self.thermalState = thermalState
        }

        /// Serious or critical thermal pressure (bible §3 / mask-slip adjacency).
        public var hasSeriousThermal: Bool {
            guard let thermal = thermalState?.lowercased() else { return false }
            return thermal.contains("serious") || thermal.contains("critical")
        }

        /// Low power or serious thermal — open (Quicksilver) turns move to Forge.
        public var forcesForgeForOpenTurn: Bool {
            isLowPower || hasSeriousThermal
        }
    }

    /// Minimum dwell before an autonomous aspect change is allowed.
    public let minimumDwellSeconds: TimeInterval

    public init(minimumDwellSeconds: TimeInterval = 15 * 60) {
        self.minimumDwellSeconds = minimumDwellSeconds
    }

    /// Evaluate preferred Aspect.
    /// Returns nil when no change is recommended (respects dwell).
    public func preferredAspect(
        current: Aspect,
        lastChangedAt: Date?,
        intent: Intent?,
        isLowPower: Bool = false,
        thermalState: String? = nil,
        hasRecentMemoryHints: Bool = false
    ) -> Aspect? {

        // Respect dwell — avoid thrashing
        if let last = lastChangedAt,
           Date().timeIntervalSince(last) < minimumDwellSeconds {
            return nil
        }

        if let candidate = fromIntent(intent) {
            return prefer(candidate, over: current)
        }

        // Environmental pressure tilts toward Forge (precision / conservation)
        if isLowPower {
            return prefer(.forge, over: current)
        }
        if let thermal = thermalState?.lowercased(),
           thermal.contains("serious") || thermal.contains("critical") {
            return prefer(.forge, over: current)
        }

        // Substantial recent memory tilts toward Eternal (continuity)
        if hasRecentMemoryHints {
            return prefer(.eternal, over: current)
        }

        return nil
    }

    /// Immediate mapping from a single Intent (no dwell check).
    /// Used by Brain for the current turn's visual and expression bias.
    public func aspectForTurn(intent: Intent) -> Aspect {
        aspectForTurn(intent: intent, environment: Environment())
    }

    /// Turn mapping with environment (P-T18): low power or serious thermal
    /// moves an **open** (Quicksilver) turn to Forge. Intent-selected Forge
    /// or Eternal is unchanged. Returns Forge even when the open aspect
    /// already matched intent, so the Brain still switches.
    public func aspectForTurn(intent: Intent, environment: Environment) -> Aspect {
        let base = fromIntent(intent) ?? .quicksilver
        if environment.forcesForgeForOpenTurn, base == .quicksilver {
            return .forge
        }
        return base
    }

    // MARK: - Mapping

    private func fromIntent(_ intent: Intent?) -> Aspect? {
        guard let intent else { return nil }
        switch intent.kind {
        case .create, .diagnose:
            return .forge
        case .observe, .retrieve, .remember:
            return .eternal
        case .inquire, .express:
            return .quicksilver
        case .switchAspect:
            // Explicit switch requests are handled by caller; policy stays neutral
            return nil
        case .unknown:
            return nil
        }
    }

    private func prefer(_ candidate: Aspect, over current: Aspect) -> Aspect? {
        candidate == current ? nil : candidate
    }
}
