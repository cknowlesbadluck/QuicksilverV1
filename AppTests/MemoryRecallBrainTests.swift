import Synchronization
import XCTest
@testable import Quicksilver
import Core
import ServicesAI

/// Recall questions are answered from notes with zero provider calls; misses still use the model.
@MainActor
final class MemoryRecallBrainTests: XCTestCase {
    func testRecallAnswersFromMemoryWithoutModel() async throws {
        let provider = CallCounter()
        let container = try ViewModelTestSupport.makeContainer(provider: provider, testCase: self)
        container.featureFlags.set("aiServiceEnabled", enabled: true)
        await container.brain.remember("My bike is a blue Brompton")
        container.aiService.routeLog.clear()
        let result = try await container.brain.askWithAspect("What did I tell you about my bike?")
        XCTAssertTrue(result.text.contains("blue Brompton"))
        XCTAssertEqual(result.provenance, .memory)
        XCTAssertEqual(result.provenance?.badge, "From memory")
        XCTAssertEqual(provider.calls, 0)
        XCTAssertEqual(container.aiService.routeLog.recent().first?.route, .memoryRecall)
        XCTAssertFalse(container.aiService.routeLog.recent().first?.summary.contains("Brompton") ?? true)
    }

    func testRecallMissFallsBackToModel() async throws {
        let provider = CallCounter()
        let container = try ViewModelTestSupport.makeContainer(provider: provider, testCase: self)
        container.featureFlags.set("aiServiceEnabled", enabled: true)
        let result = try await container.brain.askWithAspect("What did I tell you about Lisbon?")
        XCTAssertNil(result.provenance)
        XCTAssertEqual(provider.calls, 1)
    }
}

private final class CallCounter: AIProvider, Sendable {
    private let count = Mutex(0)
    var calls: Int { count.withLock { $0 } }
    let id = "counter"
    let displayName = "Counter"
    let isAvailable = true
    func complete(_ request: AIRequest) async throws -> AIResponse {
        count.withLock { $0 += 1 }
        return AIResponse(requestID: request.id, content: "model answer")
    }
}
