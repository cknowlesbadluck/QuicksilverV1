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

    actor DummyGateway: IntegrationGateway {
        let id = "dummy"
        let name = "Dummy"
        let availableCapabilities: [IntegrationCapability] = []
        func initialize() async throws {}
        func listTools() async throws -> [[String: AnyCodable]] { [] }
        func validateCredentials() async throws -> Bool { true }
        func callTool(name: String, arguments: [String: AnyCodable]) async throws -> AnyCodable { .object([:]) }
    }

    func testRouterPendingTasksFiltering() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quicksilver-task-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let taskStore = IntegrationTaskStore(fileURL: url)
        let router = IntegrationRouter(gateway: DummyGateway(), tasks: taskStore)

        let task1 = try await taskStore.create(objective: "Queued Task", steps: [])
        var task2 = try await taskStore.create(objective: "Running Task", steps: [])
        task2.status = .running
        try await taskStore.update(task2)

        var task3 = try await taskStore.create(objective: "Paused Task", steps: [])
        task3.status = .paused
        try await taskStore.update(task3)

        var task4 = try await taskStore.create(objective: "Awaiting Approval Task", steps: [])
        task4.status = .awaitingApproval
        try await taskStore.update(task4)

        var task5 = try await taskStore.create(objective: "Completed Task", steps: [])
        task5.status = .completed
        try await taskStore.update(task5)

        var task6 = try await taskStore.create(objective: "Failed Task", steps: [])
        task6.status = .failed
        try await taskStore.update(task6)

        let pending = await router.pendingTasks()
        let pendingIDs = Set(pending.map(\.id))

        XCTAssertEqual(pending.count, 4)
        XCTAssertTrue(pendingIDs.contains(task1.id))
        XCTAssertTrue(pendingIDs.contains(task2.id))
        XCTAssertTrue(pendingIDs.contains(task3.id))
        XCTAssertTrue(pendingIDs.contains(task4.id))
        XCTAssertFalse(pendingIDs.contains(task5.id))
        XCTAssertFalse(pendingIDs.contains(task6.id))
    }
}
