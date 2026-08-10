import Foundation

public struct RelicID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct GlyphID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public enum CapabilityRisk: String, Codable, Sendable {
    case low
    case moderate
    case high
}

public enum DataTransmissionPolicy: String, Codable, Sendable {
    case localOnly
    case sensitive
    case restricted
    case neverTransmit
    case providerSafe
}

public struct CapabilityManifest: Sendable, Codable, Equatable {
    public let name: String
    public let version: String
    public let description: String
    public let requiredPermissions: [String]
    public let transmissionPolicy: DataTransmissionPolicy
    public let risk: CapabilityRisk

    public init(
        name: String,
        version: String = "1.0",
        description: String,
        requiredPermissions: [String] = [],
        transmissionPolicy: DataTransmissionPolicy = .localOnly,
        risk: CapabilityRisk = .low
    ) {
        self.name = name
        self.version = version
        self.description = description
        self.requiredPermissions = requiredPermissions
        self.transmissionPolicy = transmissionPolicy
        self.risk = risk
    }
}

public struct RelicRequest: Sendable, Codable, Equatable {
    public let action: String
    public let parameters: [String: String]

    public init(action: String, parameters: [String: String] = [:]) {
        self.action = action
        self.parameters = parameters
    }
}

public struct RelicResult: Sendable, Codable, Equatable {
    public let summary: String
    public let metadata: [String: String]

    public init(summary: String, metadata: [String: String] = [:]) {
        self.summary = summary
        self.metadata = metadata
    }
}

public protocol MercuryRelic: Sendable {
    var id: RelicID { get }
    var manifest: CapabilityManifest { get }
    func invoke(_ request: RelicRequest) async throws -> RelicResult
}

public protocol MercuryGlyph: Sendable {
    var id: GlyphID { get }
    var manifest: CapabilityManifest { get }
    func connect() async throws
    func disconnect() async
}

public actor RelicRegistry {
    private var relics: [RelicID: any MercuryRelic] = [:]

    public init() {}

    public func register(_ relic: any MercuryRelic) {
        relics[relic.id] = relic
    }

    public func relic(for id: RelicID) -> (any MercuryRelic)? {
        relics[id]
    }

    public func all() -> [any MercuryRelic] {
        Array(relics.values)
    }
}

public actor GlyphRegistry {
    private var glyphs: [GlyphID: any MercuryGlyph] = [:]

    public init() {}

    public func register(_ glyph: any MercuryGlyph) {
        glyphs[glyph.id] = glyph
    }

    public func glyph(for id: GlyphID) -> (any MercuryGlyph)? {
        glyphs[id]
    }

    public func all() -> [any MercuryGlyph] {
        Array(glyphs.values)
    }
}
