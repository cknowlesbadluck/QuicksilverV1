import Foundation
import XCTest

/// UserDefaults is unencrypted and included in device backups, so personal data (notes,
/// history, credentials) belongs in the device-only Keychain. Only these reviewed stores may
/// touch UserDefaults, and they hold non-personal settings or the one-time legacy migration.
/// iCloud key-value sync (`NSUbiquitousKeyValueStore`) is not allowed anywhere: data stays on device.
final class DefaultsSurfaceGuardTests: XCTestCase {
    static let allowed: Set<String> = [
        "App/DependencyContainer.swift", // injects `.standard` into the stores below
        "Core/AspectContinuityStore.swift", // last active aspect (no user content)
        "Core/FeatureFlags.swift", // on/off settings
        "Memory/MemoryStore.swift", // reads legacy defaults once, migrates to Keychain
    ]
    static let sourceDirectories = ["App", "Core", "Intents", "Memory", "Models", "Nexus", "Personas", "Services", "UI"]
    static let defaultsPattern = #"\b(UserDefaults|AppStorage|SceneStorage)\b"#
    static let iCloudPattern = #"\bNSUbiquitousKeyValueStore\b"#

    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Code without comments or string-literal text (interpolations are kept); see `SwiftCodeScanner`.
    static func codeOnly(_ text: String) -> String {
        SwiftCodeScanner.codeOnly(text)
    }

    static func matches(_ pattern: String, _ text: String) throws -> Bool {
        let code = codeOnly(text)
        return try NSRegularExpression(pattern: pattern).firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil
    }

    private func productionSources() throws -> [(path: String, text: String)] {
        var files: [(String, String)] = []
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
                files.append((String(url.path.dropFirst(Self.root.path.count + 1)), try String(contentsOf: url, encoding: .utf8)))
            }
        }
        XCTAssertFalse(files.isEmpty, "scanner found no sources")
        return files
    }

    func testOnlyReviewedStoresUseUserDefaults() throws {
        var offenders: [String] = []
        var seen: Set<String> = []
        for file in try productionSources() {
            guard try Self.matches(Self.defaultsPattern, file.text) else { continue }
            seen.insert(file.path)
            if !Self.allowed.contains(file.path) { offenders.append(file.path) }
        }
        XCTAssertEqual(offenders.sorted(), [], "UserDefaults/@AppStorage outside the reviewed stores: keep personal data in Keychain")
        XCTAssertEqual(Self.allowed.subtracting(seen).sorted(), [], "allowlist has files that no longer use UserDefaults")
    }

    func testNoICloudKeyValueSync() throws {
        let offenders = try productionSources().filter { try Self.matches(Self.iCloudPattern, $0.text) }.map(\.path)
        XCTAssertEqual(offenders, [], "NSUbiquitousKeyValueStore syncs off device")
    }

    func testPatternsCatchCodeAndIgnoreComments() throws {
        XCTAssertTrue(try Self.matches(Self.defaultsPattern, "let d = UserDefaults.standard"))
        XCTAssertTrue(try Self.matches(Self.defaultsPattern, "@AppStorage(\"k\") var k = false"))
        XCTAssertTrue(try Self.matches(Self.iCloudPattern, "NSUbiquitousKeyValueStore.default.set(1, forKey: \"k\")"))
        XCTAssertFalse(try Self.matches(Self.defaultsPattern, "/// never written to UserDefaults"))
        XCTAssertFalse(try Self.matches(Self.defaultsPattern, "/* UserDefaults\n AppStorage */ let x = 1"))
        XCTAssertFalse(try Self.matches(Self.defaultsPattern, "let userDefaultsKey = \"x\""))
        XCTAssertTrue(try Self.matches(Self.defaultsPattern, "let url = \"https://x\"; let s = UserDefaults.standard"))
        XCTAssertTrue(try Self.matches(Self.iCloudPattern, "let u = \"https://e/\\(NSUbiquitousKeyValueStore.default.string(forKey: \"p\") ?? \"\")\""))
        XCTAssertTrue(try Self.matches(Self.defaultsPattern, "let a = \"/*\"; let b = UserDefaults.standard; let c = \"*/\""))
        XCTAssertFalse(try Self.matches(Self.defaultsPattern, "let key = \"UserDefaults\""))
        XCTAssertTrue(try Self.matches(Self.defaultsPattern, "let d = { return/* settings */UserDefaults.standard }()"))
        XCTAssertFalse(try Self.matches(Self.defaultsPattern, "let m = \"\"\"\nUserDefaults\n\"\"\""))
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
