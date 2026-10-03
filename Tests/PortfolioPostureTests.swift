import XCTest
@testable import Nexus

final class PortfolioPostureTests: XCTestCase {
    func testDeployedResonanceBodyIsOwnerBlocked() throws {
        let body = """
        {"status":"not_ready","missingRequired":["SUPABASE_SERVICE_ROLE_KEY"]}
        """.data(using: .utf8)!
        let posture = PortfolioPosture.parse(plane: .resonance, httpStatus: 503, json: body)
        XCTAssertFalse(posture.ready)
        XCTAssertTrue(posture.ownerActionRequired)
        XCTAssertEqual(posture.missingRequired, ["SUPABASE_SERVICE_ROLE_KEY"])
    }

    func testNewerContractStillOwnerBlocked() throws {
        let body = """
        {"status":"not_ready","ownerActionRequired":true,"missingRequired":["SUPABASE_SERVICE_ROLE_KEY"],"contractRevision":"2026-10-03-owner-gate"}
        """.data(using: .utf8)!
        let posture = PortfolioPosture.parse(plane: .resonance, httpStatus: 503, json: body)
        XCTAssertFalse(posture.ready)
        XCTAssertTrue(posture.ownerActionRequired)
    }

    func testConduitReadyIsNotOwnerBlocked() throws {
        let body = """
        {"status":"ready","service":"conduit","version":"0.8.0","persistence":"postgres"}
        """.data(using: .utf8)!
        let posture = PortfolioPosture.parse(plane: .conduit, httpStatus: 200, json: body)
        XCTAssertTrue(posture.ready)
        XCTAssertFalse(posture.ownerActionRequired)
        XCTAssertEqual(posture.version, "0.8.0")
    }

    func testMalformedBodyFailsClosed() {
        let posture = PortfolioPosture.parse(plane: .resonance, httpStatus: 200, json: Data("not-json".utf8))
        XCTAssertFalse(posture.ready)
    }
}
