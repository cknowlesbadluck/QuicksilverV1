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
        let result = try await container.brain.askWithAspect("What did I tell you about my bike?")
        XCTAssertTrue(result.text.contains("blue Brompton"))
        XCTAssertEqual(result.provenance, .memory)
        XCTAssertEqual(result.provenance?.badge, "From memory")
        XCTAssertEqual(provider.calls, 0)
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

private final class CallCounter: AIProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.withLock { count } }
    let id = "counter"
    let displayName = "Counter"
    let isAvailable = true
    func complete(_ request: AIRequest) async throws -> AIResponse {
        lock.withLock { count += 1 }
        return AIResponse(requestID: request.id, content: "model answer")
    }
}
