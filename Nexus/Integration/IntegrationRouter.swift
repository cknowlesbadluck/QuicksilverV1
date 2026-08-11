import Foundation

public actor IntegrationRouter {
    public struct Request: Sendable, Hashable {
        public let objective: String
        public let capabilities: [IntegrationCapability]
        public let preferredProviders: [IntegrationProvider]

        public init(
            objective: String,
            capabilities: [IntegrationCapability],
            preferredProviders: [IntegrationProvider] = []
        ) {
            self.objective = objective
            self.capabilities = capabilities
            self.preferredProviders = preferredProviders
        }
    }

    public enum RouterError: Error, LocalizedError, Sendable {
        case noRoute(IntegrationCapability)

        public var errorDescription: String? {
            switch self {
            case .noRoute(let capability):
                return "No integration route is available for \(capability.rawValue)."
            }
        }
    }

    private let plane: IntegrationPlaneClient

    public init(plane: IntegrationPlaneClient) {
        self.plane = plane
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
            throw RouterError.noRoute(request.capabilities.first ?? .customAPI)
        }

        let steps = try rawSteps.map { raw -> IntegrationPlanStep in
            let data = try JSONEncoder().encode(raw)
            return try JSONDecoder().decode(IntegrationPlanStep.self, from: data)
        }

        return IntegrationPlan(objective: objective, steps: steps)
    }

    public func executeTool(
        name: String,
        arguments: [String: AnyCodable] = [:]
    ) async throws -> AnyCodable {
        try await plane.callTool(name: name, arguments: arguments)
    }
}
