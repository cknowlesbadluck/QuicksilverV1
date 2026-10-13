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

    /// Every shipped intent declared in Intents/ is reachable from an App Shortcut.
    func testEveryIntentHasAShortcut() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Intents/QuicksilverIntents.swift"), encoding: .utf8
        )
        let declared = try NSRegularExpression(pattern: #"struct (\w+Intent): AppIntent"#)
            .matches(in: source, range: NSRange(source.startIndex..., in: source))
            .compactMap { Range($0.range(at: 1), in: source).map { String(source[$0]) } }
        XCTAssertFalse(declared.isEmpty)
        for name in declared {
            XCTAssertTrue(source.contains("intent: \(name)("), "\(name) is not exposed as an App Shortcut")
        }
    }
}
