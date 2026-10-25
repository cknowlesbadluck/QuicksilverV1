import Foundation
import XCTest

/// Companion to `UncheckedSendableRatchetTests` (issue #252). `nonisolated(unsafe)` turns off
/// the compiler's data-race checks for one declaration, so it's only allowed in the files
/// listed here, with a per-file use count. Adding one fails CI. Removing one means shrinking
/// the count in the same PR.
final class NonisolatedUnsafeRatchetTests: XCTestCase {
    /// EventBusTests: these are test-local counters written by bus handlers. They're read only after
    /// `await bus.publish` or `fulfillment(of:)` returns, and each test has a single writer.
    /// They're test-only captures, not shared app state.
    private static let allowlist: [String: Int] = ["Tests/EventBusTests.swift": 8]

    private static let sourceDirectories = [
        "App", "Core", "Memory", "Models", "Nexus", "Personas", "Services", "UI", "Intents",
        "Tests", "AppTests", "UITests"
    ]
    /// This file names the pattern in string literals, so it never counts.
    private static let selfFile = "NonisolatedUnsafeRatchetTests.swift"
    private static let pattern = "nonisolated" + "(unsafe)"

    func testNoNewNonisolatedUnsafe() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var counts: [String: Int] = [:]
        for directory in Self.sourceDirectories {
            let base = root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" && url.lastPathComponent != Self.selfFile {
                let text = try String(contentsOf: url, encoding: .utf8)
                // Count code only: drop everything after `//` on each line.
                let uses = text.split(separator: "\n").filter { line in
                    let code = line.components(separatedBy: "//").first ?? ""
                    return code.contains(Self.pattern)
                }.count
                if uses > 0 { counts[String(url.path.dropFirst(root.path.count + 1))] = uses }
            }
        }
        XCTAssertEqual(counts, Self.allowlist, "nonisolated(unsafe) uses changed (issue #252); update the allowlist with a justification")
    }
}
