import Foundation

/// Fail-closed read of the three-plane portfolio gate.
/// Accepts the currently deployed Resonance ready body and the newer
/// contract that adds ownerActionRequired. Never treats a missing secret
/// as ready.
public struct PortfolioPosture: Equatable, Sendable {
    public enum Plane: String, Sendable {
        case conduit
        case resonance
        case quicksilver
    }

    public let plane: Plane
    public let httpStatus: Int
    public let ready: Bool
    public let ownerActionRequired: Bool
    public let missingRequired: [String]
    public let version: String?
    public let contractRevision: String?
    /// True only for a Resonance body that has a status and no contractRevision.
    /// That is a stale host, not a closed owner gate and not device acceptance.
    public let deployLag: Bool
    /// True when a 404 body is DEPLOYMENT_NOT_FOUND. That is an absent alias,
    /// not an owner secret and not a device failure.
    public let aliasAbsent: Bool

    public init(
        plane: Plane,
        httpStatus: Int,
        ready: Bool,
        ownerActionRequired: Bool,
        missingRequired: [String],
        version: String?,
        contractRevision: String?,
        deployLag: Bool,
        aliasAbsent: Bool = false
    ) {
        self.plane = plane
        self.httpStatus = httpStatus
        self.ready = ready
        self.ownerActionRequired = ownerActionRequired
        self.missingRequired = missingRequired
        self.version = version
        self.contractRevision = contractRevision
        self.deployLag = deployLag
        self.aliasAbsent = aliasAbsent
    }

    public static func parse(plane: Plane, httpStatus: Int, json: Data) -> PortfolioPosture {
        let raw = String(data: json, encoding: .utf8) ?? ""
        let aliasAbsent = httpStatus == 404 && raw.contains("DEPLOYMENT_NOT_FOUND")
        let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:]
        let status = object["status"] as? String
        let missing = object["missingRequired"] as? [String] ?? []
        let explicitOwner = object["ownerActionRequired"] as? Bool
        let version = object["version"] as? String
        let revision = object["contractRevision"] as? String
        let ready = httpStatus == 200 && status == "ready" && !aliasAbsent
        let ownerAction = explicitOwner ?? (!missing.isEmpty && !ready)
        let deployLag = plane == .resonance && status != nil && revision == nil && !aliasAbsent
        return PortfolioPosture(
            plane: plane,
            httpStatus: httpStatus,
            ready: ready && missing.isEmpty,
            ownerActionRequired: ownerAction && !ready && !aliasAbsent,
            missingRequired: missing,
            version: version,
            contractRevision: revision,
            deployLag: deployLag,
            aliasAbsent: aliasAbsent
        )
    }

    /// Single allowed mutation while the product host is owner-blocked.
    /// A classifier is not device acceptance and does not invent a secret.
    public static func saturationMutation(ownerBlocked: Bool, roadmapOpen: Bool, boltOpen: Bool) -> String {
        if ownerBlocked && roadmapOpen && boltOpen { return "close_noise" }
        if ownerBlocked && roadmapOpen { return "refresh_in_place" }
        if ownerBlocked { return "owner_only" }
        return "hold"
    }
}
