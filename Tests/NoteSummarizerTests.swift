import Synchronization
import XCTest
import Core
@testable import ServicesAI

/// On-device note summaries: one short line, nil when unavailable, never the cloud.
final class NoteSummarizerTests: XCTestCase {
    private let longNote = String(repeating: "Dentist moved to Thursday at 3pm; bring the insurance card. ", count: 4)

    func testAvailableModelSummarizesInOneLine() async {
        let model = SummaryModel(reply: "  Dentist moved to Thursday 3pm.\nExtra line ignored.")
        let summarizer = OnDeviceNoteSummarizer(provider: OnDeviceAIProvider(model: model))
        let summary = await summarizer.summary(of: longNote)
        XCTAssertEqual(summary, "Dentist moved to Thursday 3pm.")
        XCTAssertEqual(model.calls.count, 1)
        XCTAssertEqual(model.calls.first?.instructions, OnDeviceNoteSummarizer.instructions)
        XCTAssertTrue(model.calls.first?.prompt.contains("Dentist moved") == true)
    }

    func testUnavailableModelReturnsNilWithoutCalling() async {
        let model = SummaryModel(availability: .appleIntelligenceNotEnabled, reply: "x")
        let summary = await OnDeviceNoteSummarizer(provider: OnDeviceAIProvider(model: model)).summary(of: longNote)
        XCTAssertNil(summary)
        XCTAssertTrue(model.calls.isEmpty)
    }

    func testNoOnDeviceProviderReturnsNil() async {
        let summary = await OnDeviceNoteSummarizer(provider: nil).summary(of: longNote)
        XCTAssertNil(summary)
    }

    func testShortNoteNeedsNoSummary() async {
        let model = SummaryModel(reply: "x")
        let summary = await OnDeviceNoteSummarizer(provider: OnDeviceAIProvider(model: model)).summary(of: "Buy milk")
        XCTAssertNil(summary)
        XCTAssertTrue(model.calls.isEmpty)
    }

    func testModelFailureReturnsNil() async {
        let model = SummaryModel(reply: "x", failure: .guardrailViolation)
        let summary = await OnDeviceNoteSummarizer(provider: OnDeviceAIProvider(model: model)).summary(of: longNote)
        XCTAssertNil(summary)
    }

    func testLongNoteIsCappedBeforeTheModel() async throws {
        let model = SummaryModel(reply: "Short.")
        let huge = String(repeating: "a", count: 20_000)
        _ = await OnDeviceNoteSummarizer(provider: OnDeviceAIProvider(model: model)).summary(of: huge)
        let prompt = try XCTUnwrap(model.calls.first?.prompt)
        XCTAssertLessThanOrEqual(prompt.count, OnDeviceNoteSummarizer.maximumInputCharacters + 16)
    }

    func testCleanTrimsCapsAndRejectsEmpty() {
        XCTAssertNil(OnDeviceNoteSummarizer.clean(" \n  \n"))
        XCTAssertEqual(OnDeviceNoteSummarizer.clean("\n  Hello.  \nmore"), "Hello.")
        let capped = OnDeviceNoteSummarizer.clean(String(repeating: "b", count: 500))
        XCTAssertEqual(capped?.count, OnDeviceNoteSummarizer.maximumSummaryCharacters)
        XCTAssertEqual(capped?.last, "…")
    }

    func testProtocolSeamAcceptsAFake() async {
        let fake: any NoteSummarizing = FixedSummarizer(text: "fixed")
        let summary = await fake.summary(of: longNote)
        XCTAssertEqual(summary, "fixed")
    }

    /// No cloud fallback, guarded at source level: the summarizer only knows the on-device provider.
    func testSummarizerHasNoCloudPath() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Services/AI/OnDevice/NoteSummarizer.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        for forbidden in ["primaryProvider", "secondaryProvider", "Gateway", "URLSession", "execute(", "cloud("] {
            XCTAssertFalse(source.contains(forbidden), "note summaries must stay on device: \(forbidden)")
        }
    }
}

private struct FixedSummarizer: NoteSummarizing {
    let text: String
    func summary(of note: String) async -> String? { text }
}

private final class SummaryModel: OnDeviceLanguageModel {
    struct Call: Sendable { let instructions: String?; let prompt: String }
    let availability: OnDeviceModelAvailability
    let reply: String
    let failure: OnDeviceModelError?
    private let recorded = Mutex<[Call]>([])
    var calls: [Call] { recorded.withLock { $0 } }

    init(availability: OnDeviceModelAvailability = .available, reply: String, failure: OnDeviceModelError? = nil) {
        self.availability = availability
        self.reply = reply
        self.failure = failure
    }

    func respond(instructions: String?, prompt: String) async throws -> String {
        recorded.withLock { $0.append(Call(instructions: instructions, prompt: prompt)) }
        if let failure { throw failure }
        return reply
    }
}
