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

    func testOnlySuppliedEvidenceCounts() {
        let evidence: [OwnerGateID: String] = [.deviceArchive: "ipa-16e-5cd560d7"]
        let board = OwnerGateBoard.current(evidence: evidence)
        XCTAssertEqual(board.first { $0.id == .deviceArchive }?.proven, true)
        XCTAssertEqual(board.first { $0.id == .resonanceServiceRole }?.proven, false)
        XCTAssertEqual(board.first { $0.id == .conduitTls }?.proven, false)
        XCTAssertEqual(OwnerGateBoard.provenCount(evidence: evidence), 1)
    }
}
