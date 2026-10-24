import XCTest

/// Source-scan guard for AGENTS.md "public Apple APIs only": fails if production code reaches
/// private or undocumented API through runtime lookup, dynamic loading or private symbols.
final class PublicAPIGuardTests: XCTestCase {
    private static let productionDirectories = [
        "App", "Core", "Services", "Nexus", "Memory", "Intents", "UI", "Personas", "Models"
    ]

    private static let forbiddenPatterns: [(String, String)] = [
        (#"\bNSClassFromString\s*\("#, "runtime class lookup (NSClassFromString)"),
        (#"\bNSSelectorFromString\s*\("#, "runtime selector lookup (NSSelectorFromString)"),
        (#"\bperform(Selector)?\s*\(\s*(Selector\s*\(\s*)?""#, "perform with a string selector"),
        (#"\bdl(open|sym)\s*\("#, "dynamic loading (dlopen/dlsym)"),
        (#"@_silgen_name\b"#, "private symbol binding (@_silgen_name)"),
        (#"\b(value|setValue)\s*\([^)]*forKey(Path)?:\s*"_"#, "KVC on an underscored (private) key")
    ]

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func testProductionCodeUsesOnlyPublicAPI() throws {
        let regexes = try Self.forbiddenPatterns.map { (try NSRegularExpression(pattern: $0.0), $0.1) }
        var violations: [String] = []
        var scanned = 0
        for dir in Self.productionDirectories {
            let base = repoRoot.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = String(url.path.dropFirst(repoRoot.path.count + 1))
                let source = try String(contentsOf: url, encoding: .utf8)
                scanned += 1
                let range = NSRange(source.startIndex..., in: source)
                for (regex, reason) in regexes where regex.firstMatch(in: source, range: range) != nil {
                    violations.append("\(relative): \(reason)")
                }
            }
        }
        XCTAssertGreaterThan(scanned, 50, "scan found too few production files; is the repo root right?")
        XCTAssertEqual(violations, [], violations.joined(separator: "\n"))
    }

    /// The patterns must actually match what they claim to forbid (guards against a regex typo
    /// silently disabling the scan).
    func testPatternsCatchKnownViolations() throws {
        let samples = [
            #"let c = NSClassFromString("UIStatusBarManager")"#,
            #"let s = NSSelectorFromString("_privateThing")"#,
            #"obj.perform(Selector("_hidden"))"#,
            #"let h = dlopen(path, RTLD_NOW)"#,
            #"@_silgen_name("swift_private") func hook()"#,
            #"view.value(forKey: "_statusBar")"#
        ]
        let regexes = try Self.forbiddenPatterns.map { try NSRegularExpression(pattern: $0.0) }
        for (sample, regex) in zip(samples, regexes) {
            let range = NSRange(sample.startIndex..., in: sample)
            XCTAssertNotNil(regex.firstMatch(in: sample, range: range), "pattern missed: \(sample)")
        }
    }
}
