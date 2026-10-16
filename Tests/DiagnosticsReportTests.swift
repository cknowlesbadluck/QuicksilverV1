import XCTest
@testable import Core
@testable import ServicesAI

final class DiagnosticsReportTests: XCTestCase {
    private func report(version: String = "1.4.0", routes: [RouteRecord] = []) -> DiagnosticsReport {
        DiagnosticsReport(
            appVersion: version, build: "212", routes: routes,
            budget: CloudBudget(remaining: 7, limit: 50, day: "2026-10-16"),
            credentials: [.gatewayToken: .locked, .grokKey: .present, .geminiKey: .unreadable(-25300)],
            memoryTotal: 12, memoryNotes: 4, memoryUsingBackupStore: true, onDeviceAvailable: false
        )
    }

    func testReportsCountsStatesAndConfig() {
        let text = report(routes: [
            RouteRecord(route: .onDevice), RouteRecord(route: .onDevice),
            RouteRecord(route: .cloudMinimal, providerName: "Grok"), RouteRecord(route: .memoryRecall)
        ]).text
        XCTAssertTrue(text.contains("Version: 1.4.0 (212)"))
        XCTAssertTrue(text.contains("onDevice=2"))
        XCTAssertTrue(text.contains("cloudMinimal=1"))
        XCTAssertTrue(text.contains("memoryRecall=1"))
        XCTAssertTrue(text.contains("failed=0"))
        XCTAssertTrue(text.contains("Cloud budget: 7/50"))
        XCTAssertTrue(text.contains("Keychain Gateway token: locked"))
        XCTAssertTrue(text.contains("Keychain Grok key: present"))
        XCTAssertTrue(text.contains("Keychain Gemini key: unreadable (-25300)"))
        XCTAssertTrue(text.contains("Keychain Gateway URL: missing"))
        XCTAssertTrue(text.contains("Memory: 12 items, 4 notes, store=backup"))
        XCTAssertTrue(text.contains("Privacy gate: floor=remote may tighten, never loosen"))
        XCTAssertTrue(text.contains("On-device model: unavailable"))
    }

    /// Routes are counted by case only: the provider name and anything else on the record is dropped.
    func testRouteRecordsContributeOnlyTheirCase() {
        let text = report(routes: [RouteRecord(route: .cloudStandard, providerName: "SECRET-PROVIDER-xyz")]).text
        XCTAssertFalse(text.contains("SECRET-PROVIDER-xyz"))
        XCTAssertTrue(text.contains("cloudStandard=1"))
    }

    /// A poisoned version string can't smuggle text (only digits, dots and dashes survive).
    func testVersionStringCannotCarryContent() {
        let text = report(version: "1.0 my medication is sertraline, key=sk-abc123!").text
        XCTAssertFalse(text.contains("medication is"))
        XCTAssertFalse(text.contains("sk-abc123"))
        XCTAssertTrue(text.contains("Version: 1.0-123 (212)"), "digits, dots and dashes only")
    }

    /// Structural guarantee: the only inputs are counts, enums, Bools and two filtered version strings.
    func testNoPromptReplyMemoryOrKeyCanAppear() {
        let secrets = [
            "What is my blood test result", "Your appointment is at 3pm", "remember the gate code 4471", "sk-live-SECRETKEY"
        ]
        let text = report(routes: [RouteRecord(route: .keptOnDevice)]).text
        for secret in secrets { XCTAssertFalse(text.contains(secret)) }
        let allowedPrefixes = [
            "Quicksilver diagnostics", "Version:", "On-device model:", "Recent routes:", "Cloud budget:",
            "Keychain ", "Memory:", "Privacy gate:"
        ]
        for line in text.split(separator: "\n") {
            XCTAssertTrue(allowedPrefixes.contains { line.hasPrefix($0) }, "unexpected line: \(line)")
        }
    }
}
