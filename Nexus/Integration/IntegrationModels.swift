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
    case chat, reason, code, search, files, repo, issues
    case pullRequests = "pull-requests"
    case projectManagement = "project-management"
    case design, deploy, database, automation, oauth
    case customAPI = "custom-api"
}

public enum IntegrationTransport: String, Codable, Sendable { case api, mcp, oauth, webhook, custom }
public enum IntegrationCredentialPolicy: String, Codable, Sendable { case managed, oauth, none }
public enum IntegrationApprovalPolicy: String, Codable, Sendable { case automatic, approvalRequired }

public struct IntegrationConnector: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let provider: IntegrationProvider
    public let capabilities: [IntegrationCapability]
    public let transport: IntegrationTransport
    public let credential: IntegrationCredentialPolicy
    public let enabled: Bool
    public init(id: String, provider: IntegrationProvider, capabilities: [IntegrationCapability], transport: IntegrationTransport, credential: IntegrationCredentialPolicy, enabled: Bool) { self.id=id; self.provider=provider; self.capabilities=capabilities; self.transport=transport; self.credential=credential; self.enabled=enabled }
}

public struct IntegrationRoute: Codable, Sendable, Hashable {
    public let connectorID: String
    public let provider: IntegrationProvider
    public let reason: String
    public init(connectorID: String, provider: IntegrationProvider, reason: String) { self.connectorID=connectorID; self.provider=provider; self.reason=reason }
    enum CodingKeys: String, CodingKey { case connectorID = "connectorId", provider, reason }
}

public struct IntegrationPlanStep: Codable, Sendable, Identifiable, Hashable {
    public let order: Int
    public let capability: IntegrationCapability
    public let connectorID: String
    public let provider: IntegrationProvider
    public let approvalRequired: Bool
    public var id: Int { order }
    public init(order: Int, capability: IntegrationCapability, connectorID: String, provider: IntegrationProvider, approvalRequired: Bool) { self.order=order; self.capability=capability; self.connectorID=connectorID; self.provider=provider; self.approvalRequired=approvalRequired }
    enum CodingKeys: String, CodingKey { case order, capability; case connectorID = "connectorId"; case provider, approvalRequired }
}

public struct IntegrationPlan: Codable, Sendable, Hashable {
    public let objective: String
    public let steps: [IntegrationPlanStep]
    public init(objective: String, steps: [IntegrationPlanStep]) { self.objective=objective; self.steps=steps }
}

public struct IntegrationHealth: Codable, Sendable, Hashable {
    public let status: String
    public let connectorCount: Int
    public let enabledCount: Int
    public let secretPolicy: String
    public let architecture: String
    public init(status: String, connectorCount: Int, enabledCount: Int, secretPolicy: String, architecture: String) { self.status=status; self.connectorCount=connectorCount; self.enabledCount=enabledCount; self.secretPolicy=secretPolicy; self.architecture=architecture }
}

public struct IntegrationExecutionPolicy: Codable, Sendable, Hashable {
    public let approval: IntegrationApprovalPolicy
    public let maxAttempts: Int
    public let timeoutSeconds: Int
    public let allowFallback: Bool
    public init(approval: IntegrationApprovalPolicy = .approvalRequired, maxAttempts: Int = 3, timeoutSeconds: Int = 60, allowFallback: Bool = true) {
        self.approval=approval; self.maxAttempts=max(1,maxAttempts); self.timeoutSeconds=max(1,timeoutSeconds); self.allowFallback=allowFallback
    }
}
