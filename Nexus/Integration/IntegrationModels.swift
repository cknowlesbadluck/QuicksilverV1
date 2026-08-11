import Foundation

public enum IntegrationProvider: String, Codable, Sendable, CaseIterable {
    case openAI = "openai"
    case anthropic
    case googleAI = "google-ai"
    case xAI = "xai"
    case google
    case github
    case linear
    case cursor
    case replit
    case figma
    case vercel
    case netlify
    case supabase
    case convex
    case lovable
    case appDeploy = "appdeploy"
    case n8n
    case other
}

public enum IntegrationCapability: String, Codable, Sendable, CaseIterable {
    case chat
    case reason
    case code
    case search
    case files
    case repo
    case issues
    case pullRequests = "pull-requests"
    case projectManagement = "project-management"
    case design
    case deploy
    case database
    case automation
    case oauth
    case customAPI = "custom-api"
}

public enum IntegrationTransport: String, Codable, Sendable {
    case api
    case mcp
    case oauth
    case webhook
    case custom
}

public enum IntegrationCredentialPolicy: String, Codable, Sendable {
    case managed
    case oauth
    case none
}

public enum IntegrationTaskStatus: String, Codable, Sendable {
    case queued
    case running
    case paused
    case awaitingApproval
    case completed
    case failed
}

public enum IntegrationApprovalPolicy: String, Codable, Sendable {
    case automatic
    case approvalRequired
}

public struct IntegrationConnector: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let provider: IntegrationProvider
    public let capabilities: [IntegrationCapability]
    public let transport: IntegrationTransport
    public let credential: IntegrationCredentialPolicy
    public let enabled: Bool

    public init(id: String, provider: IntegrationProvider, capabilities: [IntegrationCapability], transport: IntegrationTransport, credential: IntegrationCredentialPolicy, enabled: Bool) {
        self.id = id
        self.provider = provider
        self.capabilities = capabilities
        self.transport = transport
        self.credential = credential
        self.enabled = enabled
    }
}

public struct IntegrationRoute: Codable, Sendable, Hashable {
    public let connectorID: String
    public let provider: IntegrationProvider
    public let reason: String

    enum CodingKeys: String, CodingKey { case connectorID = "connectorId", provider, reason }
}

public struct IntegrationPlanStep: Codable, Sendable, Identifiable, Hashable {
    public let order: Int
    public let capability: IntegrationCapability
    public let connectorID: String
    public let provider: IntegrationProvider
    public let approvalRequired: Bool
    public var id: Int { order }

    enum CodingKeys: String, CodingKey {
        case order, capability
        case connectorID = "connectorId"
        case provider, approvalRequired
    }
}

public struct IntegrationPlan: Codable, Sendable, Hashable {
    public let objective: String
    public let steps: [IntegrationPlanStep]
}

public struct IntegrationHealth: Codable, Sendable, Hashable {
    public let status: String
    public let connectorCount: Int
    public let enabledCount: Int
    public let secretPolicy: String
    public let architecture: String
}

public struct IntegrationExecutionPolicy: Codable, Sendable, Hashable {
    public let approval: IntegrationApprovalPolicy
    public let maxAttempts: Int
    public let timeoutSeconds: Int
    public let allowFallback: Bool

    public init(approval: IntegrationApprovalPolicy = .approvalRequired, maxAttempts: Int = 3, timeoutSeconds: Int = 60, allowFallback: Bool = true) {
        self.approval = approval
        self.maxAttempts = max(1, maxAttempts)
        self.timeoutSeconds = max(1, timeoutSeconds)
        self.allowFallback = allowFallback
    }
}
