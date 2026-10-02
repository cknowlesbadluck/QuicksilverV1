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
}
