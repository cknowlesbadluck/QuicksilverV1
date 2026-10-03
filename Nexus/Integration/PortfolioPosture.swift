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

    public init(plane: Plane, httpStatus: Int, ready: Bool, ownerActionRequired: Bool, missingRequired: [String], version: String?) {
        self.plane = plane
        self.httpStatus = httpStatus
        self.ready = ready
        self.ownerActionRequired = ownerActionRequired
        self.missingRequired = missingRequired
        self.version = version
    }

    public static func parse(plane: Plane, httpStatus: Int, json: Data) -> PortfolioPosture {
        let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:]
        let status = object["status"] as? String
        let missing = object["missingRequired"] as? [String] ?? []
        let explicitOwner = object["ownerActionRequired"] as? Bool
        let version = object["version"] as? String
        let ready = httpStatus == 200 && status == "ready"
        let ownerAction = explicitOwner ?? (!missing.isEmpty && !ready)
        return PortfolioPosture(
            plane: plane,
            httpStatus: httpStatus,
            ready: ready && missing.isEmpty,
            ownerActionRequired: ownerAction && !ready,
            missingRequired: missing,
            version: version
        )
    }
}
