import XCTest
@testable import Core
@testable import ServicesAI

final class PrivacyFloorTests: XCTestCase {
    private func remote(memory: String = #"{"route":"cloud","tier":"backup"}"#,
                        mainTrains: Bool = false, mainLevel: String = "standard",
                        backupLevel: String = "minimal") -> Data {
        let json = #"{"protocol":"v1","stream":["meta","delta","done","error"],"tasks":{"answer":{"route":"cloud","tier":"main"},"plan":{"route":"onDevice"},"tools":{"route":"cloud","tier":"backup"},"memory":"#
            + memory + #","summaries":{"route":"onDevice"}},"tiers":{"main":{"displayModel":"Gemini Flash","trainsOnPrompts":"#
            + "\(mainTrains)" + #","contextLevel":""# + mainLevel + #""},"backup":{"displayModel":"Groq","trainsOnPrompts":false,"contextLevel":""#
            + backupLevel + #""},"lastResort":{"displayModel":"Workers AI","trainsOnPrompts":false,"contextLevel":"standard"}},"timeouts":{"connect":10,"firstEvent":20,"idle":15,"total":90},"retry":{"maxAttempts":1,"honorRetryAfter":true}}"#
        return Data(json.utf8)
    }

    func testBundledDefaultRespectsItsOwnFloor() {
        XCTAssertTrue(AIRoutingConfig.bundledDefault.respectsPrivacyFloor())
    }

    func testRemoteCannotMovePersonalTasksToCloud() throws {
        let clamped = try AIRoutingConfig.decodeAndValidate(remote()).clampedToPrivacyFloor()
        XCTAssertEqual(clamped.tasks["memory"]?.route, .onDevice)
        XCTAssertEqual(clamped.tasks["tools"]?.route, .onDevice)
        XCTAssertNil(clamped.tasks["memory"]?.tier)
        XCTAssertEqual(clamped.tasks["answer"]?.route, .cloud, "answer is cloud in the floor; unchanged")
        XCTAssertNoThrow(try clamped.validate())
    }

    func testRemoteCannotRelabelTrainingTierOrRaiseContext() throws {
        let clamped = try AIRoutingConfig.decodeAndValidate(remote(mainTrains: false, mainLevel: "standard"))
            .clampedToPrivacyFloor()
        XCTAssertEqual(clamped.tiers["main"]?.trainsOnPrompts, true)
        XCTAssertEqual(clamped.tiers["main"]?.contextLevel, .minimal)
        XCTAssertNoThrow(try clamped.validate())
    }

    func testRemoteMayTighten() throws {
        let clamped = try AIRoutingConfig.decodeAndValidate(remote(backupLevel: "minimal")).clampedToPrivacyFloor()
        XCTAssertEqual(clamped.tiers["backup"]?.contextLevel, .minimal, "stricter than floor is kept")
    }

    func testStoreRefreshAppliesFloorBeforeCaching() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let body = remote()
        let store = RoutingConfigStore(cacheDirectoryURL: dir, fetch: { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://mercury.example.workers.dev/v1/config")!,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (body, response)
        })
        let endpoint = try GatewayEndpoint(raw: "https://mercury.example.workers.dev")
        let ok = await store.refresh(from: endpoint, deviceToken: "test-device")
        XCTAssertTrue(ok)
        XCTAssertEqual(store.loadValidated().tasks["memory"]?.route, .onDevice)
        XCTAssertEqual(store.loadValidated().tiers["main"]?.contextLevel, .minimal)

        let reloaded = RoutingConfigStore(cacheDirectoryURL: dir, fetch: { _ in throw URLError(.notConnectedToInternet) })
        XCTAssertTrue(reloaded.loadValidated().respectsPrivacyFloor())
    }
}
