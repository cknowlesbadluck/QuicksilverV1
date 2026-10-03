import XCTest
@testable import Core
@testable import ServicesAI

final class FakeStreamingProviderTests: XCTestCase {

    func testOrderedDeltas() async throws {
        let provider = FakeStreamingProvider.deltas(["Hello", ", ", "world"])
        let request = AIRequest(prompt: "greet")

        var collected: [AIStreamEvent] = []
        for try await event in provider.stream(request) {
            collected.append(event)
        }

        XCTAssertEqual(collected.count, 5)
        guard case .meta(let route, let model, let trains) = collected[0] else {
            return XCTFail("Expected meta first")
        }
        XCTAssertEqual(route, "fake")
        XCTAssertEqual(model, "fake-model")
        XCTAssertFalse(trains)
        XCTAssertEqual(collected[1], .delta("Hello"))
        XCTAssertEqual(collected[2], .delta(", "))
        XCTAssertEqual(collected[3], .delta("world"))
        guard case .done(let usage, _) = collected[4] else {
            return XCTFail("Expected done last")
        }
        XCTAssertEqual(usage?.promptTokens, 1)
        XCTAssertEqual(usage?.completionTokens, 1)
    }

    func testScriptedErrorMidStream() async {
        let provider = FakeStreamingProvider(
            events: [
                .meta(route: "fake", model: "fake-model", trainsOnPrompts: false),
                .delta("partial"),
                .delta("should-not-arrive"),
                .done(usage: nil, finishReason: .stop)
            ],
            failureIndex: 2,
            failureError: .aiRequestFailed("boom")
        )
        let request = AIRequest(prompt: "fail please")

        var collected: [AIStreamEvent] = []
        do {
            for try await event in provider.stream(request) {
                collected.append(event)
            }
            XCTFail("Expected mid-stream failure")
        } catch let error as AppError {
            guard case .aiRequestFailed(let reason) = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
            XCTAssertEqual(reason, "boom")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(collected.count, 2)
        XCTAssertEqual(collected[0], .meta(route: "fake", model: "fake-model", trainsOnPrompts: false))
        XCTAssertEqual(collected[1], .delta("partial"))
    }

    func testCancellationTerminatesWithin100ms() async throws {
        // Long inter-event delay so cancellation must interrupt sleep, not race past it.
        let provider = FakeStreamingProvider.deltas(
            ["a", "b", "c", "d"],
            delayNanoseconds: 1_000_000_000
        )
        let request = AIRequest(prompt: "slow")

        let consumer = Task<Void, Never> {
            do {
                for try await _ in provider.stream(request) {
                    // Consume until cancelled.
                }
            } catch is CancellationError {
                // Expected when the producer finishes throwing CancellationError.
            } catch {
                // Swallow other stream errors; timing + didCancelStream are the assertions.
            }
        }

        // Let the producer enter its first sleep.
        try await Task.sleep(nanoseconds: 30_000_000)

        let started = ContinuousClock.now
        consumer.cancel()
        await consumer.value
        let elapsed = started.duration(to: .now)

        XCTAssertLessThan(
            elapsed,
            Duration.milliseconds(100),
            "Cancellation should terminate within 100 ms, took \(elapsed)"
        )
        XCTAssertTrue(provider.didCancelStream, "onTermination should record cancellation")
    }

    func testDefaultStreamWrapsComplete() async throws {
        let provider = MockAIProvider()
        let request = AIRequest(prompt: "wrap me")

        var collected: [AIStreamEvent] = []
        for try await event in provider.stream(request) {
            collected.append(event)
        }

        XCTAssertEqual(collected.count, 3)
        guard case .meta(let route, let model, let trains) = collected[0] else {
            return XCTFail("Expected meta")
        }
        XCTAssertEqual(route, "mock")
        XCTAssertEqual(model, "Mock Provider")
        XCTAssertFalse(trains)
        guard case .delta(let text) = collected[1] else {
            return XCTFail("Expected delta")
        }
        XCTAssertTrue(text.contains("[Mock response]"))
        guard case .done(let usage, _) = collected[2] else {
            return XCTFail("Expected done")
        }
        XCTAssertEqual(usage?.promptTokens, 42)
        XCTAssertEqual(usage?.completionTokens, 28)
    }

    func testCompleteConcatenatesDeltas() async throws {
        let provider = FakeStreamingProvider.deltas(["Hel", "lo"])
        let response = try await provider.complete(AIRequest(prompt: "x"))
        XCTAssertEqual(response.content, "Hello")
        XCTAssertEqual(response.finishReason, .stop)
    }

    func testFailureIndexOnDoneDoesNotEmitDone() async {
        let provider = FakeStreamingProvider(
            events: [
                .meta(route: "fake", model: "fake-model", trainsOnPrompts: false),
                .delta("partial"),
                .done(usage: AIResponse.Usage(promptTokens: 1, completionTokens: 1), finishReason: .stop)
            ],
            failureIndex: 3
        )
        var collected: [AIStreamEvent] = []
        do {
            for try await event in provider.stream(AIRequest(prompt: "x")) {
                collected.append(event)
            }
            XCTFail("Expected failure instead of done")
        } catch let error as AppError {
            guard case .aiRequestFailed = error else {
                return XCTFail("Unexpected AppError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        XCTAssertEqual(collected.count, 2)
        XCTAssertFalse(collected.contains { if case .done = $0 { return true }; return false })
    }

    func testGeminiDefaultStreamReportsTrainingAndModelId() async throws {
        guard let provider = GeminiAIProvider.make(apiKey: "test-key") else {
            return XCTFail("Expected Gemini provider")
        }
        XCTAssertEqual(provider.modelIdentifier, "gemini-3.7-flash")
        XCTAssertTrue(provider.trainsOnPrompts)

        // Use a stub that fails complete quickly — we only need meta from a custom stream path.
        // Instead call stream meta via a one-shot wrapper: complete would hit the network.
        // Assert protocol surface only here; FakeStreamingProvider covers stream mechanics.
        XCTAssertEqual(provider.id, "gemini")
    }

    func testGrokDefaultStreamMetadataSurface() {
        guard let provider = GrokAIProvider.make(apiKey: "test-key") else {
            return XCTFail("Expected Grok provider")
        }
        XCTAssertEqual(provider.modelIdentifier, "grok-4.6")
        XCTAssertFalse(provider.trainsOnPrompts)
    }
}
