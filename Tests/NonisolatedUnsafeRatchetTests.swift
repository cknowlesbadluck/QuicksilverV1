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
    /// Also matches the whitespace-separated spelling Swift accepts, `nonisolated (unsafe)`.
    private static let modifierRegex = "nonisolated" + #"\s*\(\s*unsafe\s*\)"#

    func testNoNewNonisolatedUnsafe() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var counts: [String: Int] = [:]
        for directory in Self.sourceDirectories {
            let base = root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" && url.lastPathComponent != Self.selfFile {
                let text = try String(contentsOf: url, encoding: .utf8)
                let uses = Self.modifierUses(in: Self.codeOnly(text))
                if uses > 0 { counts[String(url.path.dropFirst(root.path.count + 1))] = uses }
            }
        }
        XCTAssertEqual(counts, Self.allowlist, "nonisolated(unsafe) uses changed (issue #252); update the allowlist with a justification")
    }

    /// Counts every occurrence, so two declarations on one line count as two.
    static func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// Counts the modifier in any whitespace spelling.
    static func modifierUses(in code: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: modifierRegex) else { return 0 }
        return regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
    }

    /// Swift source with `//` and nested `/* */` comments and string literals (including
    /// multi-line `"""` strings) blanked out, so only real code is counted.
    static func codeOnly(_ source: String) -> String {
        let chars = Array(source)
        var out = ""
        var index = 0
        var blockDepth = 0
        func at(_ offset: Int) -> Character? { index + offset < chars.count ? chars[index + offset] : nil }
        while index < chars.count {
            let char = chars[index]
            if blockDepth > 0 {
                if char == "/", at(1) == "*" { blockDepth += 1; index += 2; continue }
                if char == "*", at(1) == "/" { blockDepth -= 1; index += 2; continue }
                if char == "\n" { out.append(char) }
                index += 1
            } else if char == "/", at(1) == "*" {
                blockDepth = 1; index += 2
            } else if char == "/", at(1) == "/" {
                while index < chars.count, chars[index] != "\n" { index += 1 }
            } else if char == "#", let hashes = Self.rawStringHashes(chars, from: index) {
                // Extended delimiter: #"..."# (or ##"..."##); embedded quotes don't end it.
                index += hashes
                let triple = at(1) == "\"" && at(2) == "\""
                let quotes = triple ? 3 : 1
                index += quotes
                let closing = Array(String(repeating: "\"", count: quotes) + String(repeating: "#", count: hashes))
                while index < chars.count {
                    if index + closing.count <= chars.count, Array(chars[index..<index + closing.count]) == closing {
                        index += closing.count; break
                    }
                    if !triple, chars[index] == "\n" { index += 1; break }
                    index += 1
                }
                out.append("\"\"")
            } else if char == "\"" {
                let triple = at(1) == "\"" && at(2) == "\""
                index += triple ? 3 : 1
                while index < chars.count {
                    if chars[index] == "\\" { index += 2; continue }
                    if triple, chars[index] == "\"", at(1) == "\"", at(2) == "\"" { index += 3; break }
                    if !triple, chars[index] == "\"" || chars[index] == "\n" { index += 1; break }
                    index += 1
                }
                out.append("\"\"")
            } else {
                out.append(char); index += 1
            }
        }
        return out
    }

    /// Number of `#` before a `"` starting at `index`, or nil when this isn't a raw-string opener.
    static func rawStringHashes(_ chars: [Character], from index: Int) -> Int? {
        var end = index
        while end < chars.count, chars[end] == "#" { end += 1 }
        return end < chars.count && chars[end] == "\"" ? end - index : nil
    }

    func testWhitespaceSpellingAndRawStringsAreHandled() {
        let unsafe = Self.pattern
        let spaced = "nonisolated (unsafe) var e = 0\nnonisolated ( unsafe ) var f = 0"
        XCTAssertEqual(Self.modifierUses(in: Self.codeOnly(spaced)), 2)
        let raw = "let x = #\"Use \"\(unsafe)\" here\"#\nlet y = ##\"a \"# \(unsafe)\"##\n\(unsafe) var g = 0"
        XCTAssertEqual(Self.modifierUses(in: Self.codeOnly(raw)), 1, "raw strings with embedded quotes are not code")
    }

    func testScannerIgnoresCommentsAndStringsAndCountsEachUse() {
        let unsafe = Self.pattern
        let source = """
        /* \(unsafe) var a = 0 /* nested */ still comment */
        // \(unsafe) var b = 0
        let text = "\(unsafe)"
        \(unsafe) var c = 0; \(unsafe) var d = 0
        """
        XCTAssertEqual(Self.occurrences(of: unsafe, in: Self.codeOnly(source)), 2)
        XCTAssertEqual(Self.modifierUses(in: Self.codeOnly(source)), 2)
    }
}
