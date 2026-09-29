import Foundation
import Core

/// Bridge between Nexus perception and external automation surfaces (App Intents / Shortcuts).
/// Kept lightweight and privacy-first: only exposes already-collected public signals.
///
/// Main-actor isolated: `configure` mutates state that the report methods read, and its
/// only owner (`NexusCoordinator`) is `@MainActor`. This replaces `@unchecked Sendable`,
/// which let `configure` race with reads from other isolation domains.
@MainActor
public final class AutomationBridge {

    public enum Capability: String, CaseIterable, Sendable {
        case runDiagnostic
        case reportNetworkStatus
        case reportBatteryStatus
        case openNexus
        case reportOverallHealth
    }

    public private(set) var isConfigured = false
    private weak var nexus: NexusCoordinator?

    public init() {}

    /// Attach the coordinator. Default argument supports tests that only need the configured flag.
    public func configure(nexus: NexusCoordinator? = nil) {
        self.nexus = nexus
        isConfigured = true
    }

    public var availableCapabilities: [Capability] { Capability.allCases }

    // MARK: - Capability implementations

    public func reportNetworkStatus() throws -> String {
        guard isConfigured else { throw AppError.nexusNotReady }
        if let state = nexus?.state {
            var parts = [state.networkStatus]
            if state.isNetworkExpensive { parts.append("expensive") }
            if state.isNetworkConstrained { parts.append("constrained") }
            return parts.joined(separator: ", ")
        }
        return "unknown (Nexus not attached)"
    }

    public func reportBatteryStatus() throws -> String {
        guard isConfigured else { throw AppError.nexusNotReady }
        if let state = nexus?.state {
            let level = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "unknown"
            return "\(level) (\(state.batteryState))"
        }
        return "unknown (Nexus not attached)"
    }

    public func reportOverallHealth() throws -> String {
        guard isConfigured else { throw AppError.nexusNotReady }
        if let state = nexus?.state {
            return "Health \(state.overallHealthScore) | Network \(state.networkHealthScore) | Power \(state.powerHealthScore)"
        }
        return "unknown (Nexus not attached)"
    }

    public func triggerDiagnostic(named name: String) throws -> String {
        guard isConfigured else { throw AppError.nexusNotReady }

        switch name.lowercased() {
        case "network", "networkstatus":
            return try reportNetworkStatus()
        case "battery", "batterystatus":
            return try reportBatteryStatus()
        case "health", "overall", "status":
            return try reportOverallHealth()
        case "full", "all":
            let net = try reportNetworkStatus()
            let bat = try reportBatteryStatus()
            let health = try reportOverallHealth()
            return "Network: \(net) | Battery: \(bat) | \(health)"
        default:
            throw AppError.unsupportedFeature(
                "Diagnostic '\(name)' is not registered. Available: network, battery, health, full"
            )
        }
    }
}
