import Foundation

public enum CapabilityAuthorization: Sendable, Equatable {
    case allowed
    case denied(reason: String)
    case requiresUserApproval
}

public protocol CapabilityAuthorizationPolicy: Sendable {
    func authorize(_ manifest: CapabilityManifest) async -> CapabilityAuthorization
}

public struct AllowLocalLowRiskPolicy: CapabilityAuthorizationPolicy {
    public init() {}

    public func authorize(_ manifest: CapabilityManifest) async -> CapabilityAuthorization {
        if manifest.risk == .low && manifest.transmissionPolicy == .localOnly {
            return .allowed
        }
        return .requiresUserApproval
    }
}

public actor CapabilityBroker {
    private let relics: RelicRegistry
    private let glyphs: GlyphRegistry
    private let authorizationPolicy: any CapabilityAuthorizationPolicy

    public init(
        relics: RelicRegistry = RelicRegistry(),
        glyphs: GlyphRegistry = GlyphRegistry(),
        authorizationPolicy: any CapabilityAuthorizationPolicy = AllowLocalLowRiskPolicy()
    ) {
        self.relics = relics
        self.glyphs = glyphs
        self.authorizationPolicy = authorizationPolicy
    }

    public func invoke(
        relicID: RelicID,
        request: RelicRequest
    ) async throws -> RelicResult {
        guard let relic = await relics.relic(for: relicID) else {
            throw CapabilityBrokerError.relicUnavailable(relicID.rawValue)
        }

        switch await authorizationPolicy.authorize(relic.manifest) {
        case .allowed:
            return try await relic.invoke(request)
        case .denied(let reason):
            throw CapabilityBrokerError.authorizationDenied(reason)
        case .requiresUserApproval:
            throw CapabilityBrokerError.userApprovalRequired(relicID.rawValue)
        }
    }

    public func connect(glyphID: GlyphID) async throws {
        guard let glyph = await glyphs.glyph(for: glyphID) else {
            throw CapabilityBrokerError.glyphUnavailable(glyphID.rawValue)
        }

        switch await authorizationPolicy.authorize(glyph.manifest) {
        case .allowed:
            try await glyph.connect()
        case .denied(let reason):
            throw CapabilityBrokerError.authorizationDenied(reason)
        case .requiresUserApproval:
            throw CapabilityBrokerError.userApprovalRequired(glyphID.rawValue)
        }
    }
}

public enum CapabilityBrokerError: Error, Sendable, Equatable {
    case relicUnavailable(String)
    case glyphUnavailable(String)
    case authorizationDenied(String)
    case userApprovalRequired(String)
}
