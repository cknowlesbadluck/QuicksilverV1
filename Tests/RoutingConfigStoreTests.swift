import XCTest
@testable import Core
@testable import ServicesAI

final class RoutingConfigStoreTests: XCTestCase {

    func testDecodeBundledDefaultJSON() throws {
        let data = Data(AIRoutingConfig.bundledDefaultJSON.utf8)
        let config = try AIRoutingConfig.decodeAndValidate(data)
        XCTAssertEqual(config.protocolVersion, "v1")
        XCTAssertEqual(config.tasks["answer"]?.route, .cloud)
        XCTAssertEqual(config.tasks["answer"]?.tier, .main)
        XCTAssertEqual(config.tasks["plan"]?.route, .onDevice)
        XCTAssertEqual(config.tiers["main"]?.displayModel, "Gemini Flash")
        XCTAssertEqual(config.tiers["main"]?.trainsOnPrompts, true)
        XCTAssertEqual(config.tiers["main"]?.contextLevel, .minimal)
        XCTAssertEqual(config.tiers["backup"]?.displayModel, "Groq gpt-oss-120b")
        XCTAssertEqual(config.retry.maxAttempts, 1)
        let display = config.answerDisplay()
        XCTAssertEqual(display.route, "cloud / main")
        XCTAssertEqual(display.model, "Gemini Flash")
    }

    func testFixtureFileDecodes() throws {
        let data = try fixtureData("ai-routing.default.json")
        let config = try AIRoutingConfig.decodeAndValidate(data)
        XCTAssertEqual(config.protocolVersion, "v1")
        XCTAssertEqual(config.tasks["memory"]?.route, .onDevice)
    }

    func testGatewayConfigFixtureDecodesAsRouting() throws {
        let data = try gatewayFixture("config.json")
        let config = try AIRoutingConfig.decodeAndValidate(data)
        XCTAssertEqual(config.stream, ["meta", "delta", "done", "error"])
        XCTAssertEqual(config.timeouts.total, 90)
    }

    func testInvalidJSONFallsBackToBundled() throws {
        let cacheDir = makeTempCacheDir()
        let store = RoutingConfigStore(
            bundledLoader: { Data(AIRoutingConfig.bundledDefaultJSON.utf8) },
            cacheDirectoryURL: cacheDir,
            fetch: { _ in throw URLError(.notConnectedToInternet) }
        )
        // Seed an invalid cache file — store init should ignore it.
        try Data("{not-json".utf8).write(to: store.cacheFileURL)
        let recovered = RoutingConfigStore(
            bundledLoader: { Data(AIRoutingConfig.bundledDefaultJSON.utf8) },
            cacheDirectoryURL: cacheDir
        )
        let config = recovered.loadValidated()
        XCTAssertEqual(config.tiers["main"]?.displayModel, "Gemini Flash")
    }

    func testInvalidRemoteKeepsPrevious() async throws {
        let cacheDir = makeTempCacheDir()
        let store = RoutingConfigStore(
            bundledLoader: { Data(AIRoutingConfig.bundledDefaultJSON.utf8) },
            cacheDirectoryURL: cacheDir,
            fetch: { _ in
                let response = HTTPURLResponse(
                    url: URL(string: "https://mercury.example.workers.dev/v1/config")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (Data(#"{"protocol":"nope"}"#.utf8), response)
            }
        )
        let before = store.loadValidated()
        let endpoint = try GatewayEndpoint(raw: "https://mercury.example.workers.dev")
        let ok = await store.refresh(from: endpoint, deviceToken: "device-token-value")
        XCTAssertFalse(ok)
        XCTAssertEqual(store.loadValidated(), before)
    }

    func testValidRemoteUpdatesCache() async throws {
        let cacheDir = makeTempCacheDir()
        var remote = try AIRoutingConfig.decodeAndValidate(
            Data(AIRoutingConfig.bundledDefaultJSON.utf8)
        )
        // Mutate display model so we can prove the refresh stuck.
        remote = AIRoutingConfig(
            protocolVersion: remote.protocolVersion,
            stream: remote.stream,
            tasks: remote.tasks,
            tiers: [
                "main": AITierConfig(
                    displayModel: "Gemini Flash Remote",
                    trainsOnPrompts: true,
                    contextLevel: .minimal
                ),
                "backup": remote.tiers["backup"]!,
                "lastResort": remote.tiers["lastResort"]!
            ],
            timeouts: remote.timeouts,
            retry: remote.retry
        )
        let remoteData = try JSONEncoder().encode(remote)

        let store = RoutingConfigStore(
            bundledLoader: { Data(AIRoutingConfig.bundledDefaultJSON.utf8) },
            cacheDirectoryURL: cacheDir,
            fetch: { request in
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer device-token-value")
                XCTAssertNil(request.url?.query)
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (remoteData, response)
            }
        )

        let endpoint = try GatewayEndpoint(raw: "https://mercury.example.workers.dev")
        let ok = await store.refresh(from: endpoint, deviceToken: "device-token-value")
        XCTAssertTrue(ok)
        XCTAssertEqual(store.loadValidated().tiers["main"]?.displayModel, "Gemini Flash Remote")

        // New store against the same cache dir prefers the cache over bundled.
        let reloaded = RoutingConfigStore(
            bundledLoader: { Data(AIRoutingConfig.bundledDefaultJSON.utf8) },
            cacheDirectoryURL: cacheDir
        )
        XCTAssertEqual(reloaded.loadValidated().tiers["main"]?.displayModel, "Gemini Flash Remote")
    }

    func testSecretKeyInConfigIsRejected() {
        let json = """
        {"protocol":"v1","stream":["meta","delta","done","error"],"tasks":{"answer":{"route":"onDevice"},"plan":{"route":"onDevice"},"tools":{"route":"onDevice"},"memory":{"route":"onDevice"},"summaries":{"route":"onDevice"}},"tiers":{},"timeouts":{"connect":1,"firstEvent":1,"idle":1,"total":2},"retry":{"maxAttempts":0,"honorRetryAfter":false},"apiKey":"secret"}
        """
        XCTAssertThrowsError(try AIRoutingConfig.decodeAndValidate(Data(json.utf8))) { error in
            guard case AIRoutingConfigError.containsSecretKey = error else {
                return XCTFail("Expected containsSecretKey, got \(error)")
            }
        }
    }

    func testTrainsOnPromptsRequiresMinimal() {
        let json = """
        {"protocol":"v1","stream":["meta","delta","done","error"],"tasks":{"answer":{"route":"cloud","tier":"main"},"plan":{"route":"onDevice"},"tools":{"route":"onDevice"},"memory":{"route":"onDevice"},"summaries":{"route":"onDevice"}},"tiers":{"main":{"displayModel":"X","trainsOnPrompts":true,"contextLevel":"standard"}},"timeouts":{"connect":1,"firstEvent":1,"idle":1,"total":2},"retry":{"maxAttempts":0,"honorRetryAfter":false}}
        """
        XCTAssertThrowsError(try AIRoutingConfig.decodeAndValidate(Data(json.utf8))) { error in
            guard case AIRoutingConfigError.trainsRequiresMinimal = error else {
                return XCTFail("Expected trainsRequiresMinimal, got \(error)")
            }
        }
    }

    func testUnsupportedStreamEventRejected() {
        let json = """
        {"protocol":"v1","stream":["meta","delta","done","error","heartbeat"],"tasks":{"answer":{"route":"onDevice"},"plan":{"route":"onDevice"},"tools":{"route":"onDevice"},"memory":{"route":"onDevice"},"summaries":{"route":"onDevice"}},"tiers":{},"timeouts":{"connect":1,"firstEvent":1,"idle":1,"total":2},"retry":{"maxAttempts":0,"honorRetryAfter":false}}
        """
        XCTAssertThrowsError(try AIRoutingConfig.decodeAndValidate(Data(json.utf8))) { error in
            guard case AIRoutingConfigError.invalidStream = error else {
                return XCTFail("Expected invalidStream, got \(error)")
            }
        }
    }

    func testMissingRequiredTasksRejected() {
        let json = """
        {"protocol":"v1","stream":["meta","delta","done","error"],"tasks":{"foo":{"route":"onDevice"}},"tiers":{},"timeouts":{"connect":1,"firstEvent":1,"idle":1,"total":2},"retry":{"maxAttempts":0,"honorRetryAfter":false}}
        """
        XCTAssertThrowsError(try AIRoutingConfig.decodeAndValidate(Data(json.utf8))) { error in
            guard case AIRoutingConfigError.missingRequiredTasks = error else {
                return XCTFail("Expected missingRequiredTasks, got \(error)")
            }
        }
    }

    func testCamelCaseSecretKeyRejected() {
        let json = """
        {"protocol":"v1","stream":["meta","delta","done","error"],"tasks":{"answer":{"route":"onDevice"},"plan":{"route":"onDevice"},"tools":{"route":"onDevice"},"memory":{"route":"onDevice"},"summaries":{"route":"onDevice"}},"tiers":{},"timeouts":{"connect":1,"firstEvent":1,"idle":1,"total":2},"retry":{"maxAttempts":0,"honorRetryAfter":false},"geminiApiKey":"nope"}
        """
        XCTAssertThrowsError(try AIRoutingConfig.decodeAndValidate(Data(json.utf8))) { error in
            guard case AIRoutingConfigError.containsSecretKey = error else {
                return XCTFail("Expected containsSecretKey, got \(error)")
            }
        }
    }

    func testGatewayTimeoutsMapping() throws {
        let config = try AIRoutingConfig.decodeAndValidate(
            Data(AIRoutingConfig.bundledDefaultJSON.utf8)
        )
        let timeouts = config.gatewayTimeouts
        XCTAssertEqual(timeouts.connect, 10)
        XCTAssertEqual(timeouts.firstEvent, 20)
        XCTAssertEqual(timeouts.idle, 15)
        XCTAssertEqual(timeouts.total, 90)
    }

    // MARK: - Helpers

    private func makeTempCacheDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("m3-t4-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
        return try Data(contentsOf: url)
    }

    private func gatewayFixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/gateway/\(name)")
        return try Data(contentsOf: url)
    }
}
