import Foundation
import Core

/// Decides which persona should be active given current context.
/// Priority: task/intent → continuity → environmental fallbacks.
/// Pure and side-effect free so it stays easy to test and later replace with a learned policy.
public struct PersonaDecisionPolicy: Sendable {

    /// Minimum time a persona must stay active before an autonomous switch is allowed.
    public let minimumDwellSeconds: TimeInterval

    public init(minimumDwellSeconds: TimeInterval = 15 * 60) {
        self.minimumDwellSeconds = minimumDwellSeconds
    }

    /// Evaluate the preferred persona.
    /// Returns nil when no change is recommended.
    public func preferredPersona(
        current: PersonaConfiguration,
        lastSwitchedAt: Date?,
        context: PersonaContext
    ) -> PersonaConfiguration? {

        // Respect dwell time – avoid thrashing
        if let last = lastSwitchedAt,
           Date().timeIntervalSince(last) < minimumDwellSeconds {
            return nil
        }

        if let candidate = fromTaskKind(context.taskKind) {
            return prefer(candidate, over: current)
        }
        if let candidate = fromQueryIntent(context.queryIntent) {
            return prefer(candidate, over: current)
        }
        if let candidate = fromTaskDescription(context.taskDescription) {
            return prefer(candidate, over: current)
        }
        if let candidate = fromMemoryHints(context.recentMemoryHints) {
            return prefer(candidate, over: current)
        }
        if let candidate = fromFocus(context.focusName) {
            return prefer(candidate, over: current)
        }
        if let candidate = fromDevicePressure(context) {
            return prefer(candidate, over: current)
        }
        if let candidate = fromTimePeriod(context.timePeriod) {
            return prefer(candidate, over: current)
        }

        return nil
    }

    // MARK: - Signal extractors (priority order)

    private func fromTaskKind(_ kind: TaskKind?) -> PersonaConfiguration? {
        guard let kind else { return nil }
        switch kind {
        case .building, .debugging: return .forge
        case .exploring: return .quicksilver
        case .reflecting: return .eternal
        case .communicating: return .quicksilver
        case .unknown: return nil
        }
    }

    private func fromQueryIntent(_ intent: QueryIntent?) -> PersonaConfiguration? {
        guard let intent else { return nil }
        switch intent {
        case .preciseTechnical, .diagnostic: return .forge
        case .strategic, .creative: return .quicksilver
        case .reflective: return .eternal
        case .unknown: return nil
        }
    }

    private func fromTaskDescription(_ description: String?) -> PersonaConfiguration? {
        guard let text = description?.lowercased() else { return nil }

        if containsAny(text, ["architect", "implement", "refactor", "debug", "fix", "precision", "structure"]) {
            return .forge
        }
        if containsAny(text, ["idea", "brainstorm", "explore", "what if", "creative", "strategy", "option"]) {
            return .quicksilver
        }
        if containsAny(text, ["reflect", "review", "remember", "history", "long-term", "continuity", "pattern"]) {
            return .eternal
        }
        return nil
    }

    private func fromMemoryHints(_ hints: [String]) -> PersonaConfiguration? {
        // Presence of substantial recent memory tilts toward Eternal
        hints.isEmpty ? nil : .eternal
    }

    private func fromFocus(_ focusName: String?) -> PersonaConfiguration? {
        guard let focus = focusName?.lowercased() else { return nil }

        if containsAny(focus, ["work", "deep", "focus"]) { return .forge }
        if containsAny(focus, ["sleep", "rest", "wind"]) { return .eternal }
        if containsAny(focus, ["personal", "creative"]) { return .quicksilver }
        return nil
    }

    private func fromDevicePressure(_ context: PersonaContext) -> PersonaConfiguration? {
        if context.isLowPower || (context.batteryLevel ?? 1.0) < 0.20 {
            return .forge
        }
        if let thermal = context.thermalState?.lowercased(),
           containsAny(thermal, ["serious", "critical"]) {
            return .forge
        }
        return nil
    }

    private func fromTimePeriod(_ period: EventBus.TimePeriod?) -> PersonaConfiguration? {
        switch period {
        case .earlyMorning, .morning: return .forge
        case .afternoon: return .quicksilver
        case .evening, .night: return .eternal
        case .none: return nil
        }
    }

    // MARK: - Helpers

    private func prefer(
        _ candidate: PersonaConfiguration,
        over current: PersonaConfiguration
    ) -> PersonaConfiguration? {
        candidate.id == current.id ? nil : candidate
    }

    /// Efficiently checks if `text` contains any keyword in `keywords`.
    /// Performance note: Using an explicit for-in loop avoids closure allocation overhead
    /// and enables clean short-circuiting upon finding the first matching substring.
    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        for keyword in keywords where text.contains(keyword) {
            return true
        }
        return false
    }
}
