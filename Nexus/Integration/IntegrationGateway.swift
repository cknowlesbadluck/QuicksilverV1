import Foundation

/// Stable application-facing contract for the Integration Fabric.
/// Noodle Seed/MCP is one implementation, not a permanent dependency of the Nexus domain layer.
public protocol IntegrationGateway: Actor, Sendable {
    func initialize() async throws
    func listTools() async throws -> [[String: AnyCodable]]
    func callTool(name: String, arguments: [String: AnyCodable]) async throws -> AnyCodable
}

extension IntegrationPlaneClient: IntegrationGateway {}
