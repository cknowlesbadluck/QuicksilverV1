import Foundation
import XCTest

/// Direct file writes stay in a short, reviewed list of stores. A new file that writes,
/// moves, copies, removes or creates files and directories fails here, so persistence keeps
/// going through stores that choose file protection and atomic writes deliberately.
/// SwiftData and UserDefaults are covered elsewhere. To add a store, add it here in a reviewed PR.
final class FileWriteSurfaceGuardTests: XCTestCase {
    static let allowed: Set<String> = [
        "Memory/Embedding/EmbeddingIndex.swift",
        "Nexus/Integration/IntegrationEventStore.swift",
        "Nexus/Integration/IntegrationTaskStore.swift",
        "Services/AI/Gateway/RoutingConfigStore.swift",
    ]
    static let sourceDirectories = ["App", "Core", "Intents", "Memory", "Models", "Nexus", "Personas", "Services", "UI"]
    static let pattern = #"\.write\(\s*to:|\b(createFile|removeItem|moveItem|copyItem|createDirectory|replaceItemAt)\("#

    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Code without comments or string-literal text (interpolations are kept); see `FileWriteCodeScanner`.
    static func codeOnly(_ text: String) -> String {
        // CRLF: Swift reads "\r\n" as one Character, which would hide line-comment ends.
        FileWriteCodeScanner.codeOnly(text.replacingOccurrences(of: "\r\n", with: "\n"))
    }

    static func writesFiles(_ text: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let code = codeOnly(text)
        return regex.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil
    }

    func testOnlyAllowlistedFilesWriteFiles() throws {
        var offenders: [String] = []
        var seen: Set<String> = []
        for directory in Self.sourceDirectories {
            let base = Self.root.appendingPathComponent(directory)
            var isDirectory: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: base.path, isDirectory: &isDirectory) && isDirectory.boolValue,
                          "required source directory \(directory) is missing; update sourceDirectories")
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
                XCTFail("cannot enumerate \(directory)")
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let path = String(url.path.dropFirst(Self.root.path.count + 1))
                guard try Self.writesFiles(String(contentsOf: url, encoding: .utf8)) else { continue }
                seen.insert(path)
                if !Self.allowed.contains(path) { offenders.append(path) }
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "file writes outside the reviewed stores (see FileWriteSurfaceGuardTests.allowed)")
        // Stale entries: an allowlisted file that no longer matches should be removed.
        XCTAssertEqual(Self.allowed.subtracting(seen).sorted(), [], "allowlist has files that no longer write files")
    }

    func testPatternCatchesCodeAndIgnoresComments() throws {
        XCTAssertTrue(try Self.writesFiles("try data.write(to: url, options: .atomic)"))
        XCTAssertTrue(try Self.writesFiles("try fm.removeItem(at: url)"))
        XCTAssertTrue(try Self.writesFiles("try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)"))
        XCTAssertFalse(try Self.writesFiles("// try data.write(to: url)"))
        XCTAssertFalse(try Self.writesFiles("let s = \"removeItem(at:)\""))
        XCTAssertFalse(try Self.writesFiles("let d = try Data(contentsOf: url)"))
        XCTAssertTrue(try Self.writesFiles("try data.write(\n    to: url,\n    options: .atomic\n)"))
        XCTAssertTrue(try Self.writesFiles("// note\r\ntry fm.removeItem(at: url)"))
        XCTAssertTrue(try Self.writesFiles("let p = #/\"/#; try fm.removeItem(at: url)"))
    }
}

/// Removes comments and string-literal text from Swift source but keeps code inside string
/// interpolations, so `"https://…"` can't hide the rest of a line and an API named only in a
/// string isn't counted. Handles `//`, nested `/* */`, `"…"`, `"""…"""`, raw `#"…"#` and `\(…)`.
private struct FileWriteCodeScanner {
    private let chars: [Character]
    private var index = 0
    private var output = ""

    static func codeOnly(_ text: String) -> String {
        var scanner = FileWriteCodeScanner(chars: Array(text))
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
            } else if char == "#", startsExtendedRegex() {
                extendedRegex()
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

    /// `#/…/#` (any number of `#`): its body may hold `"` or `//`, which must not open a
    /// string or comment and hide the code after it.
    private func startsExtendedRegex() -> Bool {
        var offset = 0
        while let char = at(offset), char == "#" { offset += 1 }
        return at(offset) == "/"
    }

    private mutating func extendedRegex() {
        var hashes = 0
        while at(0) == "#" { hashes += 1; index += 1 }
        index += 1 // opening "/"
        output.append(" ")
        while index < chars.count {
            if chars[index] == "/" {
                var offset = 1
                while offset <= hashes, at(offset) == "#" { offset += 1 }
                if offset == hashes + 1 { index += offset; return }
            }
            if chars[index] == "\n" { output.append("\n") }
            index += 1
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
