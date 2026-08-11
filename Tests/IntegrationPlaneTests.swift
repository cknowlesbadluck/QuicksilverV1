import Foundation
import XCTest
@testable import Nexus

final class IntegrationPlaneTests: XCTestCase {
    func testProviderAndCapabilityCodableRoundTrip() throws {
        let connector = IntegrationConnector(
            id: "dev.github",
            provider: .github,
            capabilities: [.repo, .issues, .pullRequests],
            transport: .oauth,
            credential: .oauth,
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

    func testExecutionPolicyDefaultsAreSafe() {
        let policy = IntegrationExecutionPolicy()

        XCTAssertEqual(policy.approval, .approvalRequired)
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertEqual(policy.timeoutSeconds, 60)
        XCTAssertTrue(policy.allowFallback)
    }

    func testTaskStorePersistsAndReloads() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicksilver-task-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = IntegrationTaskStore(fileURL: url)
        let step = IntegrationTaskStore.TaskStep(
            order: 1,
            capability: .repo,
            connectorID: "dev.github",
            provider: .github
        )
        let created = try await store.create(objective: "Review repository", steps: [step])

        let reloaded = IntegrationTaskStore(fileURL: url)
        let restored = await reloaded.task(id: created.id)

        XCTAssertEqual(restored?.objective, "Review repository")
        XCTAssertEqual(restored?.steps.first?.connectorID, "dev.github")
        XCTAssertEqual(restored?.status, .queued)
    }

    func testTaskStorePauseAndResume() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicksilver-task-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = IntegrationTaskStore(fileURL: url)
        let task = try await store.create(objective: "Build feature", steps: [])

        try await store.markPaused(id: task.id)
        let paused = await store.task(id: task.id)?.status
        XCTAssertEqual(paused, .paused)

        let resumed = try await store.resume(id: task.id)
        XCTAssertEqual(resumed?.status, .queued)
    }

    func testEventStoreIsAppendOnlyAndRecoverable() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicksilver-events-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let taskID = UUID()
        let store = IntegrationEventStore(fileURL: url)
        _ = try await store.append(.init(taskID: taskID, type: "task.created", message: "Created"))
        _ = try await store.append(.init(taskID: taskID, type: "task.paused", message: "Paused"))

        let reloaded = IntegrationEventStore(fileURL: url)
        let events = await reloaded.events(for: taskID)

        XCTAssertEqual(events.map(\.type), ["task.created", "task.paused"])
    }
}
