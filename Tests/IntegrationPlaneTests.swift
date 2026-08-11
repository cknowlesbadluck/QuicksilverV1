import XCTest
@testable import Nexus

final class IntegrationPlaneTests: XCTestCase {
    func testProviderAndCapabilityCodableRoundTrip() throws {
        let connector = IntegrationConnector(
            id: "dev.github",
            provider: .github,
            capabilities: [.repo, .issues, .pullRequests],
            transport: "oauth",
            credential: "oauth",
            enabled: true
        )

        let data = try JSONEncoder().encode(connector)
        let decoded = try JSONDecoder().decode(IntegrationConnector.self, from: data)

        XCTAssertEqual(decoded, connector)
    }

    func testIntegrationPlanStepUsesWireKeys() throws {
        let step = IntegrationPlanStep(
            order: 1,
            capability: .pullRequests,
            connectorID: "dev.github",
            provider: .github,
            approvalRequired: true
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(step)) as? [String: Any]
        )

        XCTAssertEqual(object["connectorId"] as? String, "dev.github")
        XCTAssertEqual(object["approvalRequired"] as? Bool, true)
    }

    func testAnyCodableRoundTrip() throws {
        let value: AnyCodable = .object([
            "name": .string("Quicksilver"),
            "enabled": .bool(true),
            "count": .int(3),
            "items": .array([.string("GitHub"), .string("Linear")])
        ])

        let encoded = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: encoded)

        XCTAssertEqual(decoded, value)
    }
}
