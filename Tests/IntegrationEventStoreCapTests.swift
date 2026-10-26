import Foundation
import XCTest
@testable import Nexus

final class IntegrationEventStoreCapTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("qs-events-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.json")
    }

    func testAppendKeepsNewestWithinCap() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = IntegrationEventStore(fileURL: url, maxEvents: 3)
        let task = UUID()
        for index in 0..<5 {
            try await store.append(.init(taskID: task, type: "t", message: "m\(index)"))
        }
        let recent = await store.recent(limit: 10)
        XCTAssertEqual(recent.map(\.message), ["m2", "m3", "m4"])

        let reloaded = IntegrationEventStore(fileURL: url, maxEvents: 2)
        let messages = await reloaded.recent(limit: 10).map(\.message)
        XCTAssertEqual(messages, ["m3", "m4"], "an oversized file is trimmed on load")
    }

    func testDefaultCapAndFloor() async {
        XCTAssertEqual(IntegrationEventStore(fileURL: tempURL()).maxEvents, 1_000)
        XCTAssertEqual(IntegrationEventStore(fileURL: tempURL(), maxEvents: 0).maxEvents, 1)
    }
}
