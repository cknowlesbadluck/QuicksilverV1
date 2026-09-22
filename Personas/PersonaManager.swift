import Foundation
import Observation
import Core

/// Owns persona configuration as a projection target for MercuryBrain.
/// Aspect selection and autonomous behavior belong exclusively to MercuryBrain.
@MainActor
@Observable
public final class PersonaManager: PersonaEngine {
    public private(set) var state: PersonaState

    private let eventBus: EventBus
    private let logger: LoggerService
    private let available: [PersonaConfiguration]

    public init(
        initial: PersonaConfiguration = .quicksilver,
        available: [PersonaConfiguration] = PersonaConfiguration.all,
        eventBus: EventBus,
        logger: LoggerService,
        policy: PersonaDecisionPolicy = PersonaDecisionPolicy(),
        featureFlags: FeatureFlags? = nil
    ) {
        self.state = PersonaState(configuration: initial)
        self.available = available
        self.eventBus = eventBus
        self.logger = logger
        // Legacy policy/feature-flag parameters are intentionally ignored.
        // They remain in the initializer temporarily for source compatibility.
        _ = policy
        _ = featureFlags
    }

    public var activePersonaID: String {
        state.configuration.id
    }

    public var activeConfiguration: PersonaConfiguration {
        state.configuration
    }

    public var availableConfigurations: [PersonaConfiguration] {
        available
    }

    public var activeMemoryPolicy: MemoryPolicy {
        MemoryPolicy.policy(for: activePersonaID)
    }

    public var lastSwitchReason: String? {
        state.lastSwitchReason
    }

    /// Projection entry used by MercuryBrain. This method never chooses an aspect.
    public func switchTo(id: String) async throws {
        try await switchTo(id: id, reason: "explicit override")
    }

    public func switchTo(id: String, reason: String) async throws {
        guard let config = available.first(where: { $0.id == id }) else {
            throw AppError.personaUnavailable(id)
        }
        try await performSwitch(to: config, reason: reason)
    }

    public func switchTo(_ config: PersonaConfiguration) async throws {
        try await switchTo(id: config.id, reason: "explicit override")
    }

    public func recordInteraction() {
        state.recordInteraction()
    }

    /// Legacy context hook retained as a no-op during migration.
    /// Aspect selection is owned exclusively by MercuryBrain.
    public func updateTaskContext(
        description: String? = nil,
        kind: TaskKind? = nil,
        queryIntent: QueryIntent? = nil,
        memoryHints: [String]? = nil
    ) {
        _ = description
        _ = kind
        _ = queryIntent
        _ = memoryHints
    }

    private func performSwitch(to config: PersonaConfiguration, reason: String) async throws {
        guard config.id != state.id else { return }

        var newState = PersonaState(configuration: config)
        newState.lastSwitchedAt = Date()
        newState.lastSwitchReason = reason
        state = newState

        logger.info(
            "Projected persona configuration \(config.displayName) [\(reason)]",
            category: logger.persona
        )
        await eventBus.publish(.personaDidChange(personaID: config.id))
    }
}
