import Foundation
import XCTest

/// Hygiene guard: user content (prompts, memory text, keys) must never reach the
/// unified log as `.public`. All logging goes through `LoggerService`, which
/// defaults to `.private`. This fails on:
/// - `privacy: .public` anywhere outside `LoggerService.swift`;
/// - `isPrivate: false` on a message that interpolates a value;
/// - a direct `os.Logger` / `os_log` call with an interpolation outside `LoggerService.swift`;
/// - `print(` / `NSLog(` in shipped sources.
/// Also guards that MARKETING_VERSION / build match AppConfiguration and the ship docs.
final class LogPrivacyGuardTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let shipped = ["App", "Core", "Intents", "Memory", "Nexus", "Personas", "Services", "UI"]
    private static let loggerFile = "Core/LoggerService.swift"

    private func shippedSources() throws -> [(path: String, text: String)] {
        var out: [(String, String)] = []
        for dir in Self.shipped {
            let base = Self.root.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let rel = String(url.path.dropFirst(Self.root.path.count + 1))
                out.append((rel, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        XCTAssertFalse(out.isEmpty, "No sources found; check the repo root")
        return out
    }

    private func offenders(_ pattern: String, excluding: Set<String> = []) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        return try shippedSources().filter { !excluding.contains($0.path) }.flatMap { file in
            file.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, line in
                let text = String(line)
                guard !text.trimmingCharacters(in: .whitespaces).hasPrefix("//") else { return nil }
                let range = NSRange(text.startIndex..., in: text)
                return regex.firstMatch(in: text, range: range) == nil ? nil : "\(file.path):\(index + 1)"
            }
        }
    }

    func testNoPublicPrivacyOutsideLoggerService() throws {
        XCTAssertEqual(try offenders(#"privacy:\s*\.public"#, excluding: [Self.loggerFile]), [])
    }

    func testNoPublicOptOutWithInterpolation() throws {
        XCTAssertEqual(try offenders(#"\\\(.*isPrivate:\s*false"#), [])
    }

    /// LoggerService's methods take a plain String, so any `\\(x, privacy:)` interpolation, `os_log(` or
    /// new `Logger(subsystem:` outside LoggerService means a raw os.Logger call site.
    func testNoRawOSLoggerOutsideLoggerService() throws {
        XCTAssertEqual(try offenders(#"(\\\([^)]*,\s*privacy:|os_log\(|Logger\(subsystem:)"#, excluding: [Self.loggerFile]), [])
    }

    func testNoPrintOrNSLogInShippedCode() throws {
        XCTAssertEqual(try offenders(#"(^|[^.\w])(print|NSLog|debugPrint)\("#), [])
    }

    func testVersionAlignment() throws {
        let yml = try String(contentsOf: Self.root.appendingPathComponent("project.yml"), encoding: .utf8)
        func capture(_ pattern: String, in text: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
        let marketing = try XCTUnwrap(capture(#"MARKETING_VERSION:\s*"([^"]+)""#, in: yml))
        let build = try XCTUnwrap(capture(#"CURRENT_PROJECT_VERSION:\s*"([^"]+)""#, in: yml))
        let config = try String(contentsOf: Self.root.appendingPathComponent("Core/AppConfiguration.swift"), encoding: .utf8)
        XCTAssertEqual(capture(#"fallbackVersion = "([^"]+)""#, in: config), marketing, "AppConfiguration.version drifted")
        XCTAssertEqual(capture(#"fallbackBuild = "([^"]+)""#, in: config), build, "AppConfiguration.build drifted")
        for doc in ["README.md", "Documentation/SIDESTORE.md", "Documentation/HARDENING.md"] {
            let text = try String(contentsOf: Self.root.appendingPathComponent(doc), encoding: .utf8)
            XCTAssertTrue(text.contains("\(marketing) (**build \(build)**)") || text.contains("\(marketing) (build \(build))")
                          || text.contains("**\(marketing) (build \(build))**"), "\(doc) ship version drifted from project.yml")
            // Every "X.Y.Z (build N)" style stamp in the doc must be current, not just one of them.
            let stamp = try NSRegularExpression(pattern: #"(?<![\d.])(\d+\.\d+\.\d+)[ \t*(—-]*build[ \t]*\**[ \t]*(\d+(?:\.\d+)*)(?![\w.])"#)
            let range = NSRange(text.startIndex..., in: text)
            for match in stamp.matches(in: text, range: range) {
                let found = [1, 2].compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
                XCTAssertEqual(found, [marketing, build], "\(doc) has a stale version stamp: \(found.joined(separator: " build "))")
            }
        }
    }
}
