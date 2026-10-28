import XCTest
@testable import Core
@testable import QuicksilverIntents

/// M1-T6: Intents route exclusively through `IntelligenceSurface`.
@MainActor
final class IntentsTests: XCTestCase {

    private var fake: FakeIntelligenceSurface!

    override func setUp() async throws {
        fake = FakeIntelligenceSurface()
        IntentDependencies.shared.resetForTesting()
        IntentDependencies.shared.configure(surface: fake)
    }

    override func tearDown() async throws {
        IntentDependencies.shared.resetForTesting()
        fake = nil
    }

    func testCaptureMemoryRoutesToRemember() async throws {
        let intent = CaptureMemoryIntent(content: "ship M1-T6")
        _ = try await intent.perform()
        XCTAssertEqual(fake.rememberCalls, ["ship M1-T6"])
    }

    func testQueryNexusRoutesToAsk() async throws {
        fake.askResult = "use actors for Keychain"
        let intent = QueryNexusIntent(query: "how should I store keys?")
        _ = try await intent.perform()
        XCTAssertEqual(fake.askCalls, ["how should I store keys?"])
    }

    func testIntentInputDropsControlAndFormatCharacters() async throws {
        _ = try await CaptureMemoryIntent(content: "a\u{0}b\u{1B}[31mc\u{202E}d\u{200B}e\nf\tg").perform()
        XCTAssertEqual(fake.rememberCalls, ["ab[31mcde\nf\tg"])
        _ = try await QueryNexusIntent(query: " \u{7}hi\u{2066} ").perform()
        XCTAssertEqual(fake.askCalls, ["hi"])
        let family = "\u{1F469}\u{200D}\u{1F467} \u{0645}\u{06CC}\u{200C}\u{062E}\u{0648}\u{0627}\u{0645}"
        _ = try await CaptureMemoryIntent(content: family).perform()
        XCTAssertEqual(fake.rememberCalls.last, family, "ZWJ/ZWNJ must survive cleaning")
        do {
            _ = try await CaptureMemoryIntent(content: "\u{0}\u{200B} \u{202E}").perform()
            XCTFail("control-only content must be rejected as blank")
        } catch {}
        XCTAssertEqual(fake.rememberCalls.count, 2)
    }

    func testQueryNexusCapsLongQueries() async throws {
        let long = String(repeating: "a", count: QueryNexusIntent.maxQueryLength + 500)
        _ = try await QueryNexusIntent(query: "  \(long)  ").perform()
        XCTAssertEqual(fake.askCalls.first?.count, QueryNexusIntent.maxQueryLength)
        let short = String(repeating: "b", count: QueryNexusIntent.maxQueryLength)
        _ = try await QueryNexusIntent(query: short).perform()
        XCTAssertEqual(fake.askCalls.last, short, "a query at the cap passes unchanged")
    }

    func testCaptureMemoryTrimsAndRejectsBlankContent() async throws {
        _ = try await CaptureMemoryIntent(content: "  note  ").perform()
        XCTAssertEqual(fake.rememberCalls, ["note"])

        do {
            _ = try await CaptureMemoryIntent(content: "   \n ").perform()
            XCTFail("expected a needs-value prompt for blank content")
        } catch {
            // Expected: blank content prompts instead of storing an empty memory.
        }
        XCTAssertEqual(fake.rememberCalls, ["note"])
    }

    func testQueryNexusRejectsBlankQuery() async throws {
        do {
            _ = try await QueryNexusIntent(query: " ").perform()
            XCTFail("expected a needs-value prompt for a blank query")
        } catch {
            // Expected: blank query prompts instead of asking the brain.
        }
        XCTAssertTrue(fake.askCalls.isEmpty)
    }

    func testUnconfiguredSurfaceThrows() async {
        IntentDependencies.shared.resetForTesting()
        let intent = QueryNexusIntent(query: "ping")
        do {
            _ = try await intent.perform()
            XCTFail("expected nexusNotReady")
        } catch let error as AppError {
            guard case .nexusNotReady = error else {
                return XCTFail("unexpected AppError: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// Every surface-backed intent on a cold (unconfigured) Brain fails with the same calm typed error.
    func testEveryIntentOnColdBrainThrowsNexusNotReady() async {
        IntentDependencies.shared.resetForTesting()
        let attempts: [(String, () async throws -> Void)] = [
            ("CaptureMemory", { _ = try await CaptureMemoryIntent(content: "note").perform() }),
            ("GetContext", { _ = try await GetContextIntent().perform() }),
            ("ReportStatus", { _ = try await ReportStatusIntent().perform() }),
            ("QueryNexus", { _ = try await QueryNexusIntent(query: "ping").perform() })
        ]
        for (name, run) in attempts {
            do {
                try await run()
                XCTFail("\(name) should fail on a cold Brain")
            } catch {
                guard case .nexusNotReady? = error as? AppError else {
                    return XCTFail("\(name): unexpected \(error)")
                }
            }
        }
    }
}

// MARK: - Fake surface

@MainActor
private final class FakeIntelligenceSurface: IntelligenceSurface {
    var askCalls: [String] = []
    var rememberCalls: [String] = []
    var switchAspectCalls: [Aspect] = []
    var askResult: String = "fake-answer"
    var activeAspect: Aspect = .quicksilver
    var memories: [MemoryItem] = []
    var statusText: String = "Health 100"

    func ask(_ query: String) async throws -> String {
        askCalls.append(query)
        return askResult
    }

    func remember(_ content: String) async {
        rememberCalls.append(content)
    }

    func snapshot(limit: Int) -> [MemoryItem] {
        Array(memories.prefix(limit))
    }

    func switchAspect(to aspect: Aspect) async throws {
        switchAspectCalls.append(aspect)
        activeAspect = aspect
    }

    func statusReport() throws -> String {
        "\(activeAspect.diagnosticLabel) (\(activeAspect.rawValue)) | \(statusText)"
    }
}
