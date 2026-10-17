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
        XCTAssertFalse(FindNotesIntent.openAppWhenRun)
        XCTAssertFalse(ForgetNoteIntent.openAppWhenRun)
    }

    func testOpenDiagnosticsForegroundsTheApp() {
        XCTAssertTrue(OpenDiagnosticsIntent.openAppWhenRun)
    }

    private func intentSources() throws -> [(name: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = root.appendingPathComponent("Intents")
        let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        let urls = (walker?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
        return try urls.sorted { $0.path < $1.path }
            .map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// Every AppIntent declared anywhere in Intents/ is reachable from an App Shortcut.
    func testEveryIntentHasAShortcut() throws {
        let sources = try intentSources()
        let all = sources.map(\.text).joined(separator: "\n")
        let protocols = "AppIntent|OpenIntent|ShowInAppSearchResultsIntent|AudioPlaybackIntent|ForegroundContinuableIntent"
        let regex = try NSRegularExpression(pattern: #"struct (\w+)\s*:[^{]*\b("# + protocols + #")\b"#)
        let declared = regex.matches(in: all, range: NSRange(all.startIndex..., in: all))
            .compactMap { Range($0.range(at: 1), in: all).map { String(all[$0]) } }
        XCTAssertFalse(declared.isEmpty)
        let provider = try XCTUnwrap(all.range(of: "AppShortcutsProvider"), "No AppShortcutsProvider found")
        let shortcuts = all[provider.lowerBound...].components(separatedBy: "AppShortcut(").dropFirst()
            .map { block in block.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") } }
            .map { $0.joined(separator: "\n") }
        for name in declared {
            XCTAssertTrue(
                shortcuts.contains { $0.contains("intent: \(name)(") },
                "\(name) is not exposed as an App Shortcut"
            )
        }
    }

    /// `openAppWhenRun` is deprecated on iOS 26+ in favour of `supportedModes`.
    /// Until the intents migrate, guard the runtime contract at source level:
    /// only Open Diagnostics may declare a foreground mode.
    func testOnlyOpenDiagnosticsDeclaresForegroundMode() throws {
        let all = try intentSources().map(\.text).joined(separator: "\n")
        let regex = try NSRegularExpression(pattern: #"\b(?:struct|extension)\s+(\w+)"#)
        let matches = regex.matches(in: all, range: NSRange(all.startIndex..., in: all))
        for (index, match) in matches.enumerated() {
            guard let nameRange = Range(match.range(at: 1), in: all),
                  let start = Range(match.range, in: all)?.lowerBound else { continue }
            let end = index + 1 < matches.count
                ? (Range(matches[index + 1].range, in: all)?.lowerBound ?? all.endIndex) : all.endIndex
            let block = all[start..<end]
            let legacyForeground = block.range(
                of: #"openAppWhenRun\s*(:\s*Bool)?\s*=\s*true"#, options: .regularExpression
            ) != nil
            guard legacyForeground || (block.contains("supportedModes") && block.contains(".foreground")) else { continue }
            XCTAssertEqual(String(all[nameRange]), "OpenDiagnosticsIntent", "Only OpenDiagnosticsIntent may run in the foreground")
        }
    }
}
