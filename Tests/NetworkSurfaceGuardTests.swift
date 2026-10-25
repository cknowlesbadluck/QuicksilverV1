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

    /// Drops `//` line comments and `/* */` block comments so prose mentioning URLSession doesn't count.
    static func codeOnly(_ text: String) -> String {
        let noBlocks = text.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: "", options: .regularExpression)
        return noBlocks.components(separatedBy: "\n").map { $0.components(separatedBy: "//").first ?? "" }.joined(separator: "\n")
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
    }
}
