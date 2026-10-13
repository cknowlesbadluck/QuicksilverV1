import AppIntents
import XCTest
@testable import QuicksilverIntents

/// Priority 6: discovery and background-safety contracts for App Intents.
final class AppIntentsDiscoveryTests: XCTestCase {

    func testShortcutsStayWithinSystemLimit() {
        let count = QuicksilverShortcuts.appShortcuts.count
        XCTAssertGreaterThan(count, 0, "Shortcuts must be discoverable")
        XCTAssertLessThanOrEqual(count, 10, "iOS allows at most 10 App Shortcuts")
    }

    /// Siri/Shortcuts actions that answer in place must not launch the app,
    /// so they work from a cold start in the background.
    func testBackgroundIntentsDoNotOpenTheApp() {
        XCTAssertFalse(GetCurrentAspectIntent.openAppWhenRun)
        XCTAssertFalse(CaptureMemoryIntent.openAppWhenRun)
        XCTAssertFalse(GetContextIntent.openAppWhenRun)
        XCTAssertFalse(ReportStatusIntent.openAppWhenRun)
        XCTAssertFalse(QueryNexusIntent.openAppWhenRun)
    }

    func testOpenDiagnosticsForegroundsTheApp() {
        XCTAssertTrue(OpenDiagnosticsIntent.openAppWhenRun)
    }

    private func intentSources() throws -> [(name: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Intents")
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// Every AppIntent declared anywhere in Intents/ is reachable from an App Shortcut.
    func testEveryIntentHasAShortcut() throws {
        let sources = try intentSources()
        let all = sources.map(\.text).joined(separator: "\n")
        let regex = try NSRegularExpression(pattern: #"struct (\w+): AppIntent\b"#)
        let declared = regex.matches(in: all, range: NSRange(all.startIndex..., in: all))
            .compactMap { Range($0.range(at: 1), in: all).map { String(all[$0]) } }
        XCTAssertFalse(declared.isEmpty)
        for name in declared {
            XCTAssertTrue(all.contains("intent: \(name)("), "\(name) is not exposed as an App Shortcut")
        }
    }

    /// `openAppWhenRun` is deprecated on iOS 26+ in favour of `supportedModes`.
    /// Until the intents migrate, guard the runtime contract at source level:
    /// only Open Diagnostics may declare a foreground mode.
    func testOnlyOpenDiagnosticsDeclaresForegroundMode() throws {
        let all = try intentSources().map(\.text).joined(separator: "\n")
        let blocks = all.components(separatedBy: "struct ").dropFirst()
        for block in blocks where block.contains("supportedModes") && block.contains(".foreground") {
            XCTAssertTrue(block.hasPrefix("OpenDiagnosticsIntent"), "Only OpenDiagnosticsIntent may run in the foreground")
        }
    }
}
