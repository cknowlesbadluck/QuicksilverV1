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
        // Matches any receiver name (`service.ai`, `x.memory`), so aliasing the
        // LoggerService under a name without "logger" cannot launder a raw Logger.
        (#"(?<!category: )(?<!category:)\b\w+\??\.(general|persona|memory|ai|ui)\b"#,
         "LoggerService category read outside a category: argument"),
        // `.nexus` also names NexusCoordinator on `self`/`container`; any other receiver is flagged.
        (#"(?<!category: )(?<!category:)\b(?!self\b|container\b)\w+\??\.nexus\b"#,
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
                // Scan the whole file with comments and string-literal text blanked
                // (interpolations kept), so multiline calls, URLs in messages and
                // `isPrivate: /* why */ false` are still caught.
                let source = Self.codeOnly(raw)
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

    private enum ScanContext {
        case code(depth: Int)
        case string(multiline: Bool, hashes: Int)
    }

    /// Blanks comments (line and nested block) and string-literal text with spaces,
    /// keeping newlines, quotes and interpolated code. Handles `"""` and `#"…"#` strings.
    static func codeOnly(_ source: String) -> String {
        let chars = Array(source)
        var out = chars
        var idx = 0
        var stack: [ScanContext] = [.code(depth: 0)]
        func blank(_ pos: Int) { if pos < out.count, out[pos] != "\n" { out[pos] = " " } }
        func starts(_ pos: Int, _ token: String) -> Bool {
            let tok = Array(token)
            guard pos + tok.count <= chars.count else { return false }
            return Array(chars[pos..<(pos + tok.count)]) == tok
        }
        while idx < chars.count {
            guard let top = stack.last else { break }
            switch top {
            case .code(let depth):
                if starts(idx, "//") {
                    while idx < chars.count, chars[idx] != "\n" { blank(idx); idx += 1 }
                    continue
                }
                if starts(idx, "/*") {
                    var nest = 0
                    repeat {
                        if starts(idx, "/*") { nest += 1; blank(idx); blank(idx + 1); idx += 2 }
                        else if starts(idx, "*/") { nest -= 1; blank(idx); blank(idx + 1); idx += 2 }
                        else { blank(idx); idx += 1 }
                    } while nest > 0 && idx < chars.count
                    continue
                }
                var hashes = 0
                var look = idx
                while look < chars.count, chars[look] == "#" { hashes += 1; look += 1 }
                if look < chars.count, chars[look] == "\"" {
                    let multiline = starts(look, "\"\"\"")
                    idx = look + (multiline ? 3 : 1)
                    stack.append(.string(multiline: multiline, hashes: hashes))
                    continue
                }
                if chars[idx] == "(" {
                    stack[stack.count - 1] = .code(depth: depth + 1)
                } else if chars[idx] == ")" {
                    if depth == 0 && stack.count > 1 { stack.removeLast(); idx += 1; continue }
                    stack[stack.count - 1] = .code(depth: max(0, depth - 1))
                }
                idx += 1
            case .string(let multiline, let hashes):
                let pounds = String(repeating: "#", count: hashes)
                let close = (multiline ? "\"\"\"" : "\"") + pounds
                let escape = "\\" + pounds
                if starts(idx, escape) {
                    let next = idx + escape.count
                    if next < chars.count, chars[next] == "(" {
                        idx = next + 1
                        stack.append(.code(depth: 0))
                        continue
                    }
                    for pos in idx...min(next, chars.count - 1) { blank(pos) }
                    idx = next + 1
                    continue
                }
                if starts(idx, close) { idx += close.count; stack.removeLast(); continue }
                if !multiline && chars[idx] == "\n" { stack.removeLast(); idx += 1; continue }
                blank(idx)
                idx += 1
            }
        }
        return String(out)
    }

    private static func hits(_ sample: String) throws -> [String] {
        let source = codeOnly(sample)
        let range = NSRange(source.startIndex..., in: source)
        return try forbiddenPatterns.filter { pattern in
            try NSRegularExpression(pattern: pattern.0).firstMatch(in: source, range: range) != nil
        }.map(\.1)
    }

    func testGuardSeesThroughURLsBlockCommentsAndAliases() throws {
        XCTAssertFalse(try Self.hits(#"loggerService.info("https://example.com \(prompt)", isPrivate: false)"#).isEmpty,
                       "// inside a string must not hide the opt-out")
        XCTAssertFalse(try Self.hits("loggerService.info(prompt, isPrivate: /* why */ false)").isEmpty,
                       "block comment must not hide the opt-out")
        XCTAssertFalse(try Self.hits("let service = loggerService\nlet raw = service.ai\nraw.info(prompt)").isEmpty,
                       "category read through a renamed alias must be flagged")
        XCTAssertFalse(try Self.hits("let raw = svc.nexus").isEmpty, "nexus category alias must be flagged")
        XCTAssertTrue(try Self.hits("container.nexus.start()\nself.nexus = nexus").isEmpty)
        XCTAssertTrue(try Self.hits(#"let k = "quicksilver.memory.items" // isPrivate: false"#).isEmpty,
                      "string text and comments are not code")
        XCTAssertTrue(try Self.hits(#"logger.info("a \(x) b", category: logger.ai)"#).isEmpty)
        XCTAssertTrue(try Self.hits("/* outer /* inner */ isPrivate: false */").isEmpty, "nested block comment")
    }

    func testGuardCatchesMultilineAndAliasedLogging() throws {
        let sample = "let log = loggerService.ai\nlogger.info(prompt, isPrivate:\n  false)\nfunc f(_ l: Logger) {}\n"
        let source = Self.codeOnly(sample)
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
