import XCTest
@testable import Quicksilver

final class IntegrationFabricTests: XCTestCase {
    func testTaskStorePersistsAndResumes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let taskURL = directory.appendingPathComponent("tasks.json")
        let store = IntegrationTaskStore(fileURL: taskURL)
        let step = IntegrationTaskStore.TaskStep(order: 1, capability: .repo, connectorID: "dev.github", provider: .github)
        let created = try await store.create(objective: "Update repository", steps: [step])

        try await store.markPaused(id: created.id)
        let resumed = try await store.resume(id: created.id)

        XCTAssertEqual(resumed?.id, created.id)
        XCTAssertEqual(resumed?.status, .queued)
        XCTAssertTrue(FileManager.default.fileExists(atPath: taskURL.path))
    }

    func testEventStoreAppendsAndFiltersByTask() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let eventURL = directory.appendingPathComponent("events.json")
        let store = IntegrationEventStore(fileURL: eventURL)
        let taskID = UUID()

        _ = try await store.append(.init(taskID: taskID, type: "task.created", message: "Created"))
        _ = try await store.append(.init(taskID: UUID(), type: "task.created", message: "Other"))

        let events = await store.events(for: taskID)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.type, "task.created")
    }

    func testExecutionPolicyDefaultsToSafeApproval() {
        let policy = IntegrationExecutionPolicy()
        XCTAssertEqual(policy.approval, .approvalRequired)
        XCTAssertEqual(policy.maxAttempts, 3)
        XCTAssertTrue(policy.allowFallback)
    }
}
