import XCTest

/// Source-scan guard: user content must only reach `os.Logger` through
/// `LoggerService`, whose default interpolation is `privacy: .private`.
/// Fails if production code logs directly on an `os.Logger`, opts a message
/// into `privacy: .public`, or passes `isPrivate: false`.
final class LoggerPrivacyGuardTests: XCTestCase {

    private static let productionDirectories = [
        "App", "Core", "Services", "Nexus", "Memory", "Intents", "UI", "Personas", "Models"
    ]

    private static let allowedFiles: Set<String> = ["Core/LoggerService.swift"]

    private static let forbiddenPatterns: [(String, String)] = [
        (#"privacy:\s*\.public"#, "privacy: .public outside LoggerService"),
        (#"isPrivate:\s*false"#, "isPrivate: false (public log of a message)"),
        (#"\.(general|nexus|persona|memory|ai|ui)\.(debug|info|notice|warning|error|fault|critical|trace|log)\("#,
         "direct os.Logger call bypassing LoggerService"),
        (#"\bos_log\("#, "os_log bypassing LoggerService"),
        (#"\bNSLog\("#, "NSLog writes unredacted content"),
        // Any code that names `os.Logger` (parameter, property, annotation) or imports
        // `os` can hold a raw Logger and call it directly; only LoggerService may.
        (#"\bimport\s+os\b"#, "import os outside LoggerService"),
        (#"\bLogger\b(?!Service)"#, "os.Logger value held outside LoggerService"),
        // Untyped aliases such as `let log = loggerService.ai`: a category property may
        // only be read as the `category:` argument of a LoggerService call.
        (#"(?<!category: )(?<!category:)\b\w*[Ll]ogger\w*\??\.(general|nexus|persona|memory|ai|ui)\b"#,
         "LoggerService category read outside a category: argument")
    ]

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func testProductionCodeDoesNotBypassPrivateLogging() throws {
        var violations: [String] = []
        let regexes = try Self.forbiddenPatterns.map { (try NSRegularExpression(pattern: $0.0), $0.1) }
        var scanned = 0
        for dir in Self.productionDirectories {
            let base = repoRoot.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = String(url.path.dropFirst(repoRoot.path.count + 1))
                if Self.allowedFiles.contains(relative) { continue }
                let raw = try String(contentsOf: url, encoding: .utf8)
                scanned += 1
                // Scan the whole file (comments blanked) so multiline calls such as
                // `logger.info(prompt, isPrivate:\n false)` are still caught.
                let source = Self.blankingLineComments(raw)
                let range = NSRange(source.startIndex..., in: source)
                for (regex, reason) in regexes {
                    for match in regex.matches(in: source, range: range) {
                        let prefix = (source as NSString).substring(to: match.range.location)
                        let line = prefix.components(separatedBy: "\n").count
                        violations.append("\(relative):\(line): \(reason)")
                    }
                }
            }
        }
        XCTAssertGreaterThan(scanned, 0, "guard scanned no sources; check repo layout")
        XCTAssertTrue(violations.isEmpty, "Logging privacy violations:\n" + violations.joined(separator: "\n"))
    }

    func testLoggerServiceDefaultsToPrivate() throws {
        let url = repoRoot.appendingPathComponent("Core/LoggerService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for method in ["debug", "info", "error"] {
            let pattern = #"func "# + method + #"\([^)]*isPrivate:\s*Bool\s*=\s*true"#
            XCTAssertNotNil(source.range(of: pattern, options: .regularExpression),
                            "LoggerService.\(method) must default to isPrivate: true")
        }
        XCTAssertNil(source.range(of: #"isPrivate:\s*Bool\s*=\s*false"#, options: .regularExpression),
                     "no LoggerService method may default to public logging")
    }

    /// Replaces `//` line comments with spaces, preserving offsets and newlines.
    static func blankingLineComments(_ source: String) -> String {
        source.components(separatedBy: "\n").map { line -> String in
            guard let idx = line.range(of: "//") else { return line }
            return String(line[..<idx.lowerBound]) + String(repeating: " ", count: line.distance(from: idx.lowerBound, to: line.endIndex))
        }.joined(separator: "\n")
    }

    func testGuardCatchesMultilineAndAliasedLogging() throws {
        let sample = "let log = loggerService.ai\nlogger.info(prompt, isPrivate:\n  false)\nfunc f(_ l: Logger) {}\n"
        let source = Self.blankingLineComments(sample)
        let range = NSRange(source.startIndex..., in: source)
        let hits = try Self.forbiddenPatterns.filter { pattern in
            try NSRegularExpression(pattern: pattern.0).firstMatch(in: source, range: range) != nil
        }
        XCTAssertEqual(hits.count, 3, "expected alias, multiline opt-out and Logger param to be flagged")
        let safe = "logger.info(\"x\", category: logger.ai)\nlet s: LoggerService = .init()\n"
        let safeRange = NSRange(safe.startIndex..., in: safe)
        for pattern in Self.forbiddenPatterns {
            XCTAssertNil(try NSRegularExpression(pattern: pattern.0).firstMatch(in: safe, range: safeRange), pattern.1)
        }
    }
}
