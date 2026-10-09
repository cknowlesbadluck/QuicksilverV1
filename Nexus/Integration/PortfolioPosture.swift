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
    /// Vercel alias 404 / DEPLOYMENT_NOT_FOUND. Not an owner gate and not device acceptance.
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
        let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:]
        let status = object["status"] as? String
        let missing = object["missingRequired"] as? [String] ?? []
        let explicitOwner = object["ownerActionRequired"] as? Bool
        let version = object["version"] as? String
        let revision = object["contractRevision"] as? String
        let ready = httpStatus == 200 && status == "ready"
        let ownerAction = explicitOwner ?? (!missing.isEmpty && !ready)
        let deployLag = plane == .resonance && status != nil && revision == nil && httpStatus != 404
        let raw = String(data: json, encoding: .utf8) ?? ""
        let aliasAbsent = httpStatus == 404 || raw.contains("DEPLOYMENT_NOT_FOUND")
        return PortfolioPosture(
            plane: plane,
            httpStatus: httpStatus,
            ready: ready && missing.isEmpty && !aliasAbsent,
            ownerActionRequired: ownerAction && !ready && !aliasAbsent,
            missingRequired: missing,
            version: version,
            contractRevision: revision,
            deployLag: deployLag && !aliasAbsent,
            aliasAbsent: aliasAbsent
        )
    }
}
