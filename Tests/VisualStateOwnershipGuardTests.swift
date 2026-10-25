import Foundation
import XCTest

/// AGENTS.md: MercuryBrain owns `VisualState`; views only read it. This scans production
/// sources and fails when anything other than the brain assigns a `visualState`.
/// `SanctumViewModel` may only mirror the brain (`visualState = container.brain.visualState`).
final class VisualStateOwnershipGuardTests: XCTestCase {
    private static let owners: Set<String> = ["App/MercuryBrain.swift"]
    private static let mirrors: [String: String] = ["UI/SanctumViewModel.swift": "container.brain.visualState"]
    private static let sourceDirectories = ["App", "Core", "Memory", "Models", "Nexus", "Personas", "Services", "UI", "Intents"]

    /// `visualState = …` or `x.visualState = …` (a line break may sit before `=`), but not `==`,
    /// not `let/var visualState = …`, and not a `visualState: VisualState = …` declaration.
    private static let assignment = try? NSRegularExpression(
        pattern: #"(?<!\b(?:let|var)\s{1,8})\bvisualState\s*=(?!=)[ \t]*([^\n]*)"#
    )

    func testOnlyMercuryBrainAssignsVisualState() throws {
        let regex = try XCTUnwrap(Self.assignment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        var ownerAssignments = 0
        for directory in Self.sourceDirectories {
            let base = root.appendingPathComponent(directory)
            var isDirectory: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: base.path, isDirectory: &isDirectory) && isDirectory.boolValue,
                          "required source directory \(directory) is missing; update sourceDirectories")
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
                XCTFail("cannot enumerate \(directory)")
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let path = String(url.path.dropFirst(root.path.count + 1))
                let text = try String(contentsOf: url, encoding: .utf8)
                let code = SwiftCodeScanner.codeOnly(text) // comments and string text removed; lines kept
                let nsCode = code as NSString
                for match in regex.matches(in: code, range: NSRange(location: 0, length: nsCode.length)) {
                    let number = nsCode.substring(to: match.range.location).filter { $0 == "\n" }.count
                    let rhs = Range(match.range(at: 1), in: code).map { String(code[$0]) } ?? ""
                    if Self.owners.contains(path) {
                        ownerAssignments += 1
                    } else if let mirror = Self.mirrors[path], rhs.trimmingCharacters(in: .whitespaces) == mirror {
                        continue
                    } else {
                        offenders.append("\(path):\(number + 1)")
                    }
                }
            }
        }
        XCTAssertEqual(offenders, [], "Only MercuryBrain may set VisualState; views read it (AGENTS.md)")
        XCTAssertGreaterThan(ownerAssignments, 0, "scanner found no brain assignments: the guard is not seeing sources")
    }

    func testPatternIgnoresComparisonsAndDeclarations() throws {
        let regex = try XCTUnwrap(Self.assignment)
        func matches(_ line: String) -> Bool {
            regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
        }
        XCTAssertTrue(matches("brain.visualState = .warning"))
        XCTAssertTrue(matches("visualState=.idle"))
        XCTAssertFalse(matches("if visualState == .thinking {"))
        XCTAssertTrue(matches("visualState\n    = .warning"))
        XCTAssertFalse(matches("var visualState: VisualState = .idle"))
        XCTAssertFalse(matches("let visualState = container.brain.visualState"))
        XCTAssertFalse(matches("var visualState = brain.visualState"))
        let hidden = SwiftCodeScanner.codeOnly("let u = \"https://x\"; brain.visualState = .warning")
        XCTAssertTrue(matches(hidden), "a // inside a string must not hide the assignment")
        XCTAssertFalse(matches(SwiftCodeScanner.codeOnly("let s = \"visualState = .idle\"")))
    }
}

/// Removes comments and string-literal text from Swift source but keeps code inside string
/// interpolations, so `"https://…"` can't hide the rest of a line and an API named only in a
/// string isn't counted. Handles `//`, nested `/* */`, `"…"`, `"""…"""`, raw `#"…"#` and `\(…)`.
private struct SwiftCodeScanner {
    private let chars: [Character]
    private var index = 0
    private var output = ""

    static func codeOnly(_ text: String) -> String {
        var scanner = SwiftCodeScanner(chars: Array(text))
        scanner.code(stopAtParen: false)
        return scanner.output
    }

    private init(chars: [Character]) { self.chars = chars }

    private func at(_ offset: Int) -> Character? {
        index + offset < chars.count ? chars[index + offset] : nil
    }

    private mutating func code(stopAtParen: Bool) {
        var depth = 0
        while index < chars.count {
            let char = chars[index]
            if char == "/", at(1) == "/" {
                while index < chars.count, chars[index] != "\n" { index += 1 }
            } else if char == "/", at(1) == "*" {
                blockComment()
            } else if char == "\"" || (char == "#" && startsRawString()) {
                string()
            } else if char == "(" {
                depth += 1; output.append(char); index += 1
            } else if char == ")" {
                index += 1
                if stopAtParen && depth == 0 { return }
                depth -= 1; output.append(char)
            } else {
                output.append(char); index += 1
            }
        }
    }

    private func startsRawString() -> Bool {
        var offset = 0
        while let char = at(offset), char == "#" { offset += 1 }
        return at(offset) == "\""
    }

    private mutating func blockComment() {
        output.append(" ") // keep `return/* x */Name` as two tokens
        var depth = 0
        while index < chars.count {
            if chars[index] == "/", at(1) == "*" { depth += 1; index += 2; continue }
            if chars[index] == "*", at(1) == "/" {
                depth -= 1; index += 2
                if depth == 0 { return }
                continue
            }
            if chars[index] == "\n" { output.append("\n") }
            index += 1
        }
    }

    private mutating func string() {
        var hashes = 0
        while at(0) == "#" { hashes += 1; index += 1 }
        let multiline = at(0) == "\"" && at(1) == "\"" && at(2) == "\""
        index += multiline ? 3 : 1
        output.append("\"")
        while index < chars.count {
            let char = chars[index]
            if char == "\\" {
                var offset = 1
                while offset <= hashes, at(offset) == "#" { offset += 1 }
                if offset == hashes + 1 {
                    if at(offset) == "(" {
                        index += offset + 1
                        output.append(" ")
                        code(stopAtParen: true)
                        output.append(" ")
                    } else {
                        index += offset + 1 // escaped character
                    }
                    continue
                }
                index += 1
                continue
            }
            if closesString(multiline: multiline, hashes: hashes) {
                index += (multiline ? 3 : 1) + hashes
                output.append("\"")
                return
            }
            if char == "\n" {
                if !multiline { return } // unterminated single-line string
                output.append("\n")
            }
            index += 1
        }
    }

    private func closesString(multiline: Bool, hashes: Int) -> Bool {
        let quotes = multiline ? 3 : 1
        for offset in 0..<quotes where at(offset) != "\"" { return false }
        for offset in 0..<hashes where at(quotes + offset) != "#" { return false }
        return true
    }
}
