import Foundation

public actor IntegrationRouter {
    public struct Request: Sendable, Hashable {
        public let objective: String
        public let capabilities: [IntegrationCapability]
        public let preferredProviders: [IntegrationProvider]
        public let policy: IntegrationExecutionPolicy

        public init(objective: String, capabilities: [IntegrationCapability], preferredProviders: [IntegrationProvider] = [], policy: IntegrationExecutionPolicy = .init()) {
            self.objective = objective
            self.capabilities = capabilities
            self.preferredProviders = preferredProviders
            self.policy = policy
        }
    }

    public enum RouterError: Error, LocalizedError, Sendable {
        case noRoute(IntegrationCapability)
        case malformedPlan

        public var errorDescription: String? {
            switch self {
            case .noRoute(let capability): return "No integration route is available for \(capability.rawValue)."
            case .malformedPlan: return "The integration plane returned a malformed execution plan."
            }
        }
    }

    private let plane: IntegrationPlaneClient
    private let tasks: IntegrationTaskStore
    private let events: IntegrationEventStore

    public init(plane: IntegrationPlaneClient, tasks: IntegrationTaskStore = .init(), events: IntegrationEventStore = .init()) {
        self.plane = plane
        self.tasks = tasks
        self.events = events
    }

    public func plan(_ request: Request) async throws -> IntegrationPlan {
        let arguments: [String: AnyCodable] = [
            "objective": .string(request.objective),
            "capabilities": .array(request.capabilities.map { .string($0.rawValue) }),
            "preferredProviders": .array(request.preferredProviders.map { .string($0.rawValue) })
        ]
        let result = try await plane.callTool(name: "integration_plan", arguments: arguments)
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
    /// If the current agent dies immediately afterward, another agent/session can resume this task.
    public func createTask(_ request: Request) async throws -> IntegrationTaskStore.Task {
        let executionPlan = try await plan(request)
        let steps = executionPlan.steps.map {
            IntegrationTaskStore.TaskStep(order: $0.order, capability: $0.capability, connectorID: $0.connectorID, provider: $0.provider)
        }
        let task = try await tasks.create(objective: request.objective, steps: steps)
        _ = try await events.append(.init(taskID: task.id, type: "task.created", message: request.objective))
        return task
    }

    public func pauseTask(_ id: UUID) async throws {
        try await tasks.markPaused(id: id)
        _ = try await events.append(.init(taskID: id, type: "task.paused", message: "Task paused and persisted."))
    }

    public func resumeTask(_ id: UUID) async throws -> IntegrationTaskStore.Task? {
        let task = try await tasks.resume(id: id)
        if task != nil {
            _ = try await events.append(.init(taskID: id, type: "task.resumed", message: "Task resumed from persistent state."))
        }
        return task
    }

    public func pendingTasks() async -> [IntegrationTaskStore.Task] {
        await tasks.all().filter { [.queued, .running, .paused, .awaitingApproval].contains($0.status) }
    }

    public func executeTool(name: String, arguments: [String: AnyCodable] = [:]) async throws -> AnyCodable {
        try await plane.callTool(name: name, arguments: arguments)
    }
}
