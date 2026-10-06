import Foundation

/// Same exit rules as the Conduit/Resonance phase ledger.
/// A 404 alias is not the service-role gate. Simulator CI is not device HG.
public struct PortfolioPhaseLedger {
    public static let ownerSecret = "SUPABASE_SERVICE_ROLE_KEY"
    public static let contractRevision = "2026-10-03-ready-surface"

    public struct Probe: Equatable {
        public let service: String
        public let httpStatus: Int
        public let missingRequired: [String]
        public let persistence: String?
        public let contractRevision: String?
        public let aliasAbsent: Bool

        public init(service: String, httpStatus: Int, missingRequired: [String] = [], persistence: String? = nil, contractRevision: String? = nil, aliasAbsent: Bool = false) {
            self.service = service
            self.httpStatus = httpStatus
            self.missingRequired = missingRequired
            self.persistence = persistence
            self.contractRevision = contractRevision
            self.aliasAbsent = aliasAbsent
        }
    }

    public struct State: Equatable {
        public let phase: Int
        public let name: String
        public let advanced: Bool
        public let reason: String
    }

    public static func advance(probes: [Probe], deviceHgPassed: Bool = false) -> State {
        let conduit = probes.first { $0.service == "conduit" }
        let stable = conduit?.httpStatus == 200 && conduit?.persistence == "postgres" && conduit?.contractRevision == contractRevision
        if !stable {
            return State(phase: 0, name: "stabilize_hosts", advanced: false, reason: "Conduit /ready is not postgres 0.8.0 with the ready-surface stamp.")
        }
        let resonance = probes.first { $0.service == "resonance" }
        let ownerBlocked = resonance?.missingRequired.contains(ownerSecret) == true
        let ready = resonance?.httpStatus == 200 && resonance?.missingRequired.isEmpty == true
        if ownerBlocked || !ready {
            let alias = probes.first { $0.service == "vercel_alias" && $0.httpStatus == 404 && $0.aliasAbsent }
            let note = alias == nil ? "" : " Vercel alias is absent, not the owner gate."
            return State(phase: 1, name: "owner_ready_gate", advanced: false, reason: "Resonance /api/ready is blocked on \(ownerSecret). Do not invent it.\(note)")
        }
        if !deviceHgPassed {
            return State(phase: 5, name: "ios_device_gate", advanced: false, reason: "Simulator CI is not the iPhone 16e device HG gate.")
        }
        return State(phase: 9, name: "release_lock", advanced: true, reason: "Device HG passed after the owner gate. Release lock is allowed.")
    }
}
