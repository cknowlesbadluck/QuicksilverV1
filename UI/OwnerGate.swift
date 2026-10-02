import Foundation

/// Portfolio ship gates that this app cannot close by itself.
/// A gate is proven only when the caller supplies evidence that is not blank
/// and does not describe a simulator or CI job. Missing evidence is owner work.
enum OwnerGateID: String, CaseIterable, Sendable {
    case deviceArchive
    case resonanceServiceRole
    case conduitTls
}

struct OwnerGate: Equatable, Identifiable, Sendable {
    let id: OwnerGateID
    let title: String
    let ownerAction: String
    let evidence: String?

    var proven: Bool {
        OwnerGateBoard.accepts(evidence)
    }

    var statusLabel: String {
        proven ? "Proven" : "Owner"
    }
}

enum OwnerGateBoard {
    /// Tokens that must never count as ship proof. A green simulator job is not an archive.
    static let rejectedEvidenceTokens = [
        "simulator",
        "github actions",
        "ci green",
        "not acceptance"
    ]

    static func accepts(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        let lowered = trimmed.lowercased()
        return !rejectedEvidenceTokens.contains { lowered.contains($0) }
    }

    /// Default board has no evidence. Do not invent IPA, secret, or TLS proof.
    static func current(evidence: [OwnerGateID: String] = [:]) -> [OwnerGate] {
        OwnerGateID.allCases.map { id in
            OwnerGate(
                id: id,
                title: title(for: id),
                ownerAction: ownerAction(for: id),
                evidence: evidence[id]
            )
        }
    }

    static func provenCount(evidence: [OwnerGateID: String] = [:]) -> Int {
        current(evidence: evidence).filter(\.proven).count
    }

    private static func title(for id: OwnerGateID) -> String {
        switch id {
        case .deviceArchive: "Device archive"
        case .resonanceServiceRole: "Resonance ready"
        case .conduitTls: "Conduit TLS"
        }
    }

    private static func ownerAction(for id: OwnerGateID) -> String {
        switch id {
        case .deviceArchive:
            "Archive an IPA on iPhone 16e. Simulator CI is not acceptance."
        case .resonanceServiceRole:
            "Set the production service-role key on resonancenexus. Do not invent it."
        case .conduitTls:
            "Set the Render Postgres TLS env before verifying database certificates."
        }
    }
}
