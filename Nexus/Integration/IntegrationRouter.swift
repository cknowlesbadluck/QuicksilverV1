import Foundation

public actor IntegrationRouter {
    public struct Request: Sendable, Hashable {
        public let objective: String
        public let capabilities: [IntegrationCapability]
        public let preferredProviders: [IntegrationProvider]
        public let policy: IntegrationExecutionPolicy

        public init(
            objective: String,
            capabilities: [IntegrationCapability],
            preferredProviders: [IntegrationProvider] = [],
            policy: IntegrationExecutionPolicy = IntegrationExecutionPolicy()
        ) {
            self.objective = objective
            self.capabilities = capabilities
            self.preferredProviders = preferredProviders
            self.policy = policy
        }
    }

    public enum RouterError: Error, LocalizedError, Sendable {
        case noRoute(IntegrationCapability)
        case malformedPlan
        case approvalRequired

        public var errorDescription: String? {
            switch self {
            case .noRoute(let capability):
                return "No integration route is available for \(capability.rawValue)."
            case .malformedPlan:
                return "The integration gateway returned a malformed execution plan."
            case .approvalRequired:
                return "Explicit approval is required before executing an integration tool."
            }
        }
    }

    private let gateway: any IntegrationGateway
    private let tasks: IntegrationTaskStore
    private let events: IntegrationEventStore

    public init(
        gateway: any IntegrationGateway,
        tasks: IntegrationTaskStore = IntegrationTaskStore(),
        events: IntegrationEventStore = IntegrationEventStore()
    ) {
        self.gateway = gateway
        self.tasks = tasks
        self.events = events
    }

    public func plan(_ request: Request) async throws -> IntegrationPlan {
        let arguments: [String: AnyCodable] = [
            "objective": .string(request.objective),
            "capabilities": .array(request.capabilities.map { .string($0.rawValue) }),
            "preferredProviders": .array(request.preferredProviders.map { .string($0.rawValue) })
        ]
        let result = try await gateway.callTool(name: "integration_plan", arguments: arguments)

        guard case let .object(object) = result,
              case let .string(objective) = object["objective"],
              case let .array(rawSteps) = object["steps"] else {
            throw RouterError.malformedPlan
        }

        let steps = try rawSteps.map { raw -> IntegrationPlanStep in
            let data = try JSONEncoder().encode(raw)
            return try JSONDecoder().decode(IntegrationPlanStep.self, from: data)
        }
        return IntegrationPlan(objective: objective, steps: steps)
    }

    /// Creates durable work state before any consequential execution occurs.
    /// Another agent or session can resume the persisted task.
    public func createTask(_ request: Request) async throws -> IntegrationTaskStore.Task {
        let executionPlan = try await plan(request)
        let steps = executionPlan.steps.map {
            IntegrationTaskStore.TaskStep(order: $0.order, capability: $0.capability, connectorID: $0.connectorID, provider: $0.provider)
        }
        let task = try await tasks.create(objective: request.objective, steps: steps)
        _ = try await events.append(
            IntegrationEventStore.Event(taskID: task.id, type: "task.created", message: "Task created.")
        )
        return task
    }

    public func pauseTask(_ id: UUID) async throws {
        try await tasks.markPaused(id: id)
        _ = try await events.append(IntegrationEventStore.Event(taskID: id, type: "task.paused", message: "Task paused and persisted."))
    }

    public func resumeTask(_ id: UUID) async throws -> IntegrationTaskStore.Task? {
        let task = try await tasks.resume(id: id)
        if task != nil {
            _ = try await events.append(
                IntegrationEventStore.Event(taskID: id, type: "task.resumed", message: "Task resumed from persistent state.")
            )
        }
        return task
    }

    public func pendingTasks() async -> [IntegrationTaskStore.Task] {
        await tasks.all().filter { [.queued, .running, .paused, .awaitingApproval].contains($0.status) }
    }

    public func executeTool(
        name: String,
        arguments: [String: AnyCodable] = [:],
        policy: IntegrationExecutionPolicy = IntegrationExecutionPolicy()
    ) async throws -> AnyCodable {
        guard policy.approval == .automatic else {
            throw RouterError.approvalRequired
        }
        try Task.checkCancellation()
        return try await gateway.callTool(name: name, arguments: arguments)
    }
}
