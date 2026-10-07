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
        XCTAssertTrue(posture.deployLag)
        XCTAssertNil(posture.contractRevision)
    }

    func testNewerContractStillOwnerBlocked() throws {
        let body = """
        {"status":"not_ready","ownerActionRequired":true,"missingRequired":["SUPABASE_SERVICE_ROLE_KEY"],"contractRevision":"2026-10-03-owner-gate"}
        """.data(using: .utf8)!
        let posture = PortfolioPosture.parse(plane: .resonance, httpStatus: 503, json: body)
        XCTAssertFalse(posture.ready)
        XCTAssertTrue(posture.ownerActionRequired)
        XCTAssertFalse(posture.deployLag)
        XCTAssertEqual(posture.contractRevision, "2026-10-03-owner-gate")
    }

    func testConduitReadyIsNotOwnerBlocked() throws {
        let body = """
        {"status":"ready","service":"conduit","version":"0.8.0","persistence":"postgres"}
        """.data(using: .utf8)!
        let posture = PortfolioPosture.parse(plane: .conduit, httpStatus: 200, json: body)
        XCTAssertTrue(posture.ready)
        XCTAssertFalse(posture.ownerActionRequired)
        XCTAssertEqual(posture.version, "0.8.0")
        XCTAssertFalse(posture.deployLag)
    }

    func testMalformedBodyFailsClosed() {
        let posture = PortfolioPosture.parse(plane: .resonance, httpStatus: 200, json: Data("not-json".utf8))
        XCTAssertFalse(posture.ready)
        XCTAssertFalse(posture.deployLag)
        XCTAssertFalse(posture.aliasAbsent)
    }

    func testVercel404IsAliasAbsenceNotOwnerGate() {
        let body = Data("The deployment could not be found on Vercel. DEPLOYMENT_NOT_FOUND".utf8)
        let posture = PortfolioPosture.parse(plane: .resonance, httpStatus: 404, json: body)
        XCTAssertTrue(posture.aliasAbsent)
        XCTAssertFalse(posture.ready)
        XCTAssertFalse(posture.ownerActionRequired)
        XCTAssertFalse(posture.deployLag)
    }

    func testSaturationClosesBoltNoiseWithoutOpeningWork() {
        XCTAssertEqual(
            PortfolioPosture.saturationMutation(ownerBlocked: true, roadmapOpen: true, boltOpen: true),
            "close_noise"
        )
        XCTAssertEqual(
            PortfolioPosture.saturationMutation(ownerBlocked: true, roadmapOpen: true, boltOpen: false),
            "refresh_in_place"
        )
    }
}
