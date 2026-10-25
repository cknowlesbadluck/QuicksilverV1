import Foundation
import XCTest

/// Network I/O stays in a short, reviewed list of clients. A new file that opens a
/// `URLSession`, builds a `URLRequest`, or uses Network.framework fails here. Network code
/// should go through an existing client so the privacy gate, redirect rejection and
/// Keychain-held credentials keep applying. To add a client, add it here in a reviewed PR.
final class NetworkSurfaceGuardTests: XCTestCase {
    static let allowed: Set<String> = [
        "Nexus/Integration/IntegrationPlaneClient.swift",
        "Nexus/NetworkMonitor.swift", // NWPathMonitor reachability only; sends nothing
        "Services/AI/AIService.swift", // gateway health fetcher type (URLRequest in, response out)
        "Services/AI/Gateway/RoutingConfigStore.swift", // routing config fetcher type
        "Services/AI/Gateway/GatewayAIProvider.swift",
        "Services/AI/Gateway/GatewayStreamTransport.swift",
        "Services/AI/GatewayEndpoint.swift",
        "Services/AI/GeminiAIProvider.swift",
        "Services/AI/GrokAIProvider.swift",
    ]
    static let sourceDirectories = ["App", "Core", "Intents", "Memory", "Models", "Nexus", "Personas", "Services", "UI"]
    static let pattern = #"\b(URLSession|URLRequest|NWConnection|NWListener|NWBrowser|CFStreamCreatePairWithSocket|URLSessionWebSocketTask)\b|^\s*import\s+Network\b"#

    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Code without comments or string-literal text (interpolations are kept); see `SwiftCodeScanner`.
    static func codeOnly(_ text: String) -> String {
        SwiftCodeScanner.codeOnly(text)
    }

    static func usesNetwork(_ text: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let code = codeOnly(text)
        return regex.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil
    }

    func testOnlyAllowlistedFilesDoNetworkIO() throws {
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
                guard try Self.usesNetwork(String(contentsOf: url, encoding: .utf8)) else { continue }
                seen.insert(path)
                if !Self.allowed.contains(path) { offenders.append(path) }
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "network I/O outside the reviewed clients (see NetworkSurfaceGuardTests.allowed)")
        // Stale entries: an allowlisted file that no longer does network I/O should be removed.
        XCTAssertEqual(Self.allowed.subtracting(seen).sorted(), [], "allowlist has files that no longer do network I/O")
    }

    func testPatternCatchesCodeAndIgnoresComments() throws {
        XCTAssertTrue(try Self.usesNetwork("let s = URLSession.shared"))
        XCTAssertTrue(try Self.usesNetwork("var r = URLRequest(url: u)"))
        XCTAssertTrue(try Self.usesNetwork("import Network\nlet c = 1"))
        XCTAssertFalse(try Self.usesNetwork("// URLSession is not used here"))
        XCTAssertFalse(try Self.usesNetwork("/* URLRequest\n NWConnection */ let x = 1"))
        XCTAssertFalse(try Self.usesNetwork("let urlSessionCount = 1"))
        XCTAssertTrue(try Self.usesNetwork("let url = \"https://x\"; let s = URLSession.shared"))
        XCTAssertTrue(try Self.usesNetwork("let u = \"a\\(URLSession.shared.description)\""))
        XCTAssertTrue(try Self.usesNetwork("let a = \"/*\"; let r = URLRequest(url: u); let c = \"*/\""))
        XCTAssertFalse(try Self.usesNetwork("let label = \"URLSession\""))
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
