import Foundation

/// Selects the active Aspect of the single Quicksilver entity.
/// Pure and side-effect free. Consumes Core.Intent + lightweight context.
///
/// Priority: strong Intent signal → continuity / environmental fallbacks.
/// Does not own persona switching; callers (MercuryBrain) map Aspect →
/// existing PersonaConfiguration during the transition period.
public struct AspectPolicy: Sendable {

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
        fromIntent(intent) ?? .quicksilver
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
