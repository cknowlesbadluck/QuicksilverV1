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
        (#"\bNSLog\("#, "NSLog writes unredacted content")
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
                let source = try String(contentsOf: url, encoding: .utf8)
                scanned += 1
                for (lineNumber, line) in source.components(separatedBy: .newlines).enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") { continue }
                    let range = NSRange(line.startIndex..., in: line)
                    for (regex, reason) in regexes where regex.firstMatch(in: line, range: range) != nil {
                        violations.append("\(relative):\(lineNumber + 1): \(reason)")
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
        let defaults = source.components(separatedBy: "isPrivate: Bool = true").count - 1
        XCTAssertEqual(defaults, 3, "debug/info/error must default to isPrivate: true")
    }
}
