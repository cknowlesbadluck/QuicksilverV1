import Foundation

public enum AIProviderRole: String, Codable, CaseIterable, Sendable {
    case primary
    case secondary
    case fallback
}

public struct AIProviderRoute: Sendable, Equatable {
    public let providerID: String
    public let role: AIProviderRole

    public init(providerID: String, role: AIProviderRole) {
        self.providerID = providerID
        self.role = role
    }
}

/// Contextual routing policy for Mercury's free-tier provider stack.
/// Provider implementations remain outside Core; this type only owns ordering and selection policy.
public struct MercuryProviderPolicy: Sendable, Equatable {
    public let primary: AIProviderRoute
    public let secondary: AIProviderRoute
    public let fallback: AIProviderRoute

    public init(
        primary: AIProviderRoute = .init(providerID: "gemini", role: .primary),
        secondary: AIProviderRoute = .init(providerID: "groq", role: .secondary),
        fallback: AIProviderRoute = .init(providerID: "openrouter-free", role: .fallback)
    ) {
        self.primary = primary
        self.secondary = secondary
        self.fallback = fallback
    }

    public var orderedRoutes: [AIProviderRoute] {
        [primary, secondary, fallback]
    }
}

public enum AIProviderFailure: Error, Sendable, Equatable {
    case unavailable
    case rateLimited
    case timeout
    case unsupportedCapability
    case transient
    case policyDenied
}

/// Routes a request through the configured primary → secondary → fallback stack.
/// Capability and privacy policy checks are expected to happen before a route is attempted.
public actor MercuryProviderRouter {
    private let policy: MercuryProviderPolicy
    private var providers: [String: any AIProvider]

    public init(
        policy: MercuryProviderPolicy = MercuryProviderPolicy(),
        providers: [any AIProvider] = []
    ) {
        self.policy = policy
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
    }

    public func register(_ provider: any AIProvider) {
        providers[provider.id] = provider
    }

    public func routes() -> [AIProviderRoute] {
        policy.orderedRoutes
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        var lastError: Error?

        for route in policy.orderedRoutes {
            guard let provider = providers[route.providerID], provider.isAvailable else {
                lastError = AIProviderFailure.unavailable
                continue
            }

            do {
                return try await provider.complete(request)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AIProviderFailure.unavailable
    }
}
