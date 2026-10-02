import XCTest
@testable import Quicksilver

final class OwnerGateTests: XCTestCase {
    func testDefaultBoardProvesNothing() {
        let board = OwnerGateBoard.current()
        XCTAssertEqual(board.count, 3)
        XCTAssertEqual(OwnerGateBoard.provenCount(), 0)
        XCTAssertTrue(board.allSatisfy { !$0.proven })
        XCTAssertTrue(board.allSatisfy { $0.statusLabel == "Owner" })
    }

    func testBlankEvidenceIsNotProof() {
        let board = OwnerGateBoard.current(evidence: [.deviceArchive: "   "])
        XCTAssertEqual(board.first { $0.id == .deviceArchive }?.proven, false)
        XCTAssertEqual(OwnerGateBoard.provenCount(evidence: [.deviceArchive: "   "]), 0)
    }

    func testSimulatorTextIsNotDeviceProof() {
        let claims = [
            "simulator UI smoke green",
            "CI green on 0015d46",
            "GitHub Actions passed",
            "not acceptance"
        ]
        for claim in claims {
            XCTAssertFalse(OwnerGateBoard.accepts(claim), claim)
            let board = OwnerGateBoard.current(evidence: [.deviceArchive: claim])
            XCTAssertEqual(board.first { $0.id == .deviceArchive }?.proven, false, claim)
        }
        XCTAssertEqual(OwnerGateBoard.provenCount(evidence: [.deviceArchive: "simulator UI smoke green"]), 0)
    }

    func testOnlySuppliedEvidenceCounts() {
        let evidence: [OwnerGateID: String] = [.deviceArchive: "ipa-16e-5cd560d7"]
        let board = OwnerGateBoard.current(evidence: evidence)
        XCTAssertEqual(board.first { $0.id == .deviceArchive }?.proven, true)
        XCTAssertEqual(board.first { $0.id == .resonanceServiceRole }?.proven, false)
        XCTAssertEqual(board.first { $0.id == .conduitTls }?.proven, false)
        XCTAssertEqual(OwnerGateBoard.provenCount(evidence: evidence), 1)
    }

    func testLiveProbeWitnessIsContextNotProof() {
        let witness = OwnerGateBoard.latestProbe
        XCTAssertFalse(witness.countsAsProof)
        XCTAssertEqual(witness.resonanceStatus, "not_ready")
        XCTAssertEqual(witness.missingRequired, ["SUPABASE_SERVICE_ROLE_KEY"])
        XCTAssertEqual(witness.conduitVersion, "0.8.0")
        XCTAssertFalse(OwnerGateBoard.accepts(witness.summary))
        XCTAssertEqual(
            OwnerGateBoard.provenCount(evidence: [.resonanceServiceRole: witness.summary]),
            0
        )
        XCTAssertFalse(witness.summary.contains("eyJ"))
    }

    func testFreshWitnessIsStillNotProof() {
        let observed = ProbeWitness.parse("2026-10-02T14:02:18Z")
        XCTAssertNotNil(observed)
        let thirtyMinutesLater = observed!.addingTimeInterval(30 * 60)
        XCTAssertFalse(OwnerGateBoard.latestProbe.isStale(asOf: thirtyMinutesLater))
        XCTAssertEqual(OwnerGateBoard.latestProbe.freshnessLabel(asOf: thirtyMinutesLater), "Fresh witness")
        XCTAssertFalse(OwnerGateBoard.latestProbe.countsAsProof)
        XCTAssertTrue(OwnerGateBoard.latestProbe.deployLag)
        XCTAssertFalse(OwnerGateBoard.accepts(OwnerGateBoard.latestProbe.footer(asOf: thirtyMinutesLater)))
    }

    func testWitnessOlderThanWindowIsStaleAndStillNotProof() {
        let witness = ProbeWitness(
            probedAt: "2026-10-02T08:01:44Z",
            resonanceStatus: "not_ready",
            missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
            conduitStatus: "ready",
            conduitVersion: "0.8.0",
            missingContractFields: ["ownerActionRequired"]
        )
        let observed = ProbeWitness.parse(witness.probedAt)
        XCTAssertNotNil(observed)
        let pastWindow = observed!.addingTimeInterval(OwnerGateBoard.maxWitnessAge + 60)
        XCTAssertTrue(witness.isStale(asOf: pastWindow))
        XCTAssertEqual(witness.freshnessLabel(asOf: pastWindow), "Stale witness")
        XCTAssertFalse(witness.countsAsProof)
        XCTAssertFalse(OwnerGateBoard.accepts(witness.footer(asOf: pastWindow)))
    }

    func testUnparseableTimestampIsStale() {
        let witness = ProbeWitness(
            probedAt: "not-a-date",
            resonanceStatus: "not_ready",
            missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
            conduitStatus: "ready",
            conduitVersion: "0.8.0",
            missingContractFields: []
        )
        XCTAssertTrue(witness.isStale(asOf: Date()))
        XCTAssertFalse(witness.deployLag)
        XCTAssertFalse(witness.countsAsProof)
    }
}
