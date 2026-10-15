import XCTest

/// Module-boundary tripwire (AGENTS.md: "Keep modules small and directional. No upward
/// dependencies into UI or App."). Source-level, so it also covers the XcodeGen project,
/// where target dependencies are looser than in Package.swift.
final class ModuleBoundaryTests: XCTestCase {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Directory → imports it must never use.
    static let forbidden: [String: Set<String>] = [
        "Core": ["Memory", "Personas", "ServicesAI", "Nexus", "QuicksilverIntents", "Quicksilver",
                 "SwiftUI", "UIKit", "SwiftData"],
        "Memory": ["Personas", "ServicesAI", "Nexus", "QuicksilverIntents", "Quicksilver", "SwiftUI", "UIKit"],
        "Personas": ["Memory", "ServicesAI", "Nexus", "QuicksilverIntents", "Quicksilver", "SwiftUI", "UIKit"],
        "Services": ["Memory", "Personas", "Nexus", "QuicksilverIntents", "Quicksilver", "SwiftUI", "UIKit"],
        // Nexus is persona-agnostic; UIKit is allowed (battery, behind canImport).
        "Nexus": ["Memory", "Personas", "ServicesAI", "QuicksilverIntents", "Quicksilver", "SwiftUI"],
        // Intents reach intelligence only through the Brain (IntelligenceSurface).
        "Intents": ["Memory", "ServicesAI", "Nexus", "Quicksilver"]
    ]

    func testNoIllegalImportEdges() throws {
        var offenders: [String] = []
        for (directory, banned) in Self.forbidden {
            for (path, text) in try swiftFiles(in: directory) {
                for line in text.split(separator: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("import ") || trimmed.hasPrefix("@testable import ") else { continue }
                    let module = trimmed.split(separator: " ").last.map(String.init) ?? ""
                    if banned.contains(module) { offenders.append("\(path): \(trimmed)") }
                }
            }
        }
        XCTAssertEqual(offenders, [], "Illegal module edge (see AGENTS.md)")
    }

    func testEveryGuardedDirectoryExists() {
        for directory in Self.forbidden.keys {
            XCTAssertTrue(FileManager.default.fileExists(atPath: Self.repoRoot.appendingPathComponent(directory).path), directory)
        }
    }

    private func swiftFiles(in directory: String) throws -> [(String, String)] {
        let base = Self.repoRoot.appendingPathComponent(directory)
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        var result: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(Self.repoRoot.path.count + 1))
            result.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return result
    }
}
