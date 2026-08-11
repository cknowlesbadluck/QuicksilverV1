import Foundation

/// Coordinates durable multi-provider work independently of any particular AI agent.
/// The coordinator is intentionally separate from the transport client so Noodle Seed can be replaced later.
public actor IntegrationTaskCoordinator {
    public enum CoordinatorError: Error, LocalizedError, Sendable {
        case malformedPlan

        public var errorDescription: String? {
            switch self {
            case .malformedPlan:
                return "The integration gateway returned a malformed execution plan."
            }
        }
    }

    private let gateway: any IntegrationGateway
    private let tasks: IntegrationTaskStore
    private let events: IntegrationEventStore

    public init(gateway: any IntegrationGateway, tasks: IntegrationTaskStore = .init(), events: IntegrationEventStore = .init()) {
        self.gateway = gateway
        self.tasks = tasks
        self.events = events
    }

    public func create(objective: String, capabilities: [IntegrationCapability], preferredProviders: [IntegrationProvider] = []) async throws -> IntegrationTaskStore.Task {
        let result = try await gateway.callTool(
            name: "integration_plan",
            arguments: [
                "objective": .string(objective),
                "capabilities": .array(capabilities.map { .string($0.rawValue) }),
                "preferredProviders": .array(preferredProviders.map { .string($0.rawValue) })
            ]
        )

        guard case let .object(object) = result,
              case let .array(rawSteps) = object["steps"] else {
            throw CoordinatorError.malformedPlan
        }

        let planSteps = try rawSteps.map { raw -> IntegrationPlanStep in
            let data = try JSONEncoder().encode(raw)
            return try JSONDecoder().decode(IntegrationPlanStep.self, from: data)
        }

        let steps = planSteps.map {
            IntegrationTaskStore.TaskStep(
                order: $0.order,
                capability: $0.capability,
                connectorID: $0.connectorID,
                provider: $0.provider
            )
        }

        let task = try await tasks.create(objective: objective, steps: steps)
        _ = try await events.append(.init(taskID: task.id, type: "task.created", message: objective))
        return task
    }

    public func pause(_ id: UUID) async throws {
        try await tasks.markPaused(id: id)
        _ = try await events.append(.init(taskID: id, type: "task.paused", message: "Task paused."))
    }

    public func resume(_ id: UUID) async throws -> IntegrationTaskStore.Task? {
        let task = try await tasks.resume(id: id)
        if task != nil {
            _ = try await events.append(.init(taskID: id, type: "task.resumed", message: "Task resumed."))
        }
        return task
    }

    public func pending() async -> [IntegrationTaskStore.Task] {
        await tasks.all().filter {
            [.queued, .running, .paused, .awaitingApproval].contains($0.status)
        }
    }

    public func events(for taskID: UUID) async -> [IntegrationEventStore.Event] {
        await events.events(for: taskID)
    }
}
