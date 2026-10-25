import Foundation
import XCTest

/// AGENTS.md: MercuryBrain owns `VisualState`; views only read it. This scans production
/// sources and fails when anything other than the brain assigns a `visualState`.
/// `SanctumViewModel` may only mirror the brain (`visualState = container.brain.visualState`).
final class VisualStateOwnershipGuardTests: XCTestCase {
    private static let owners: Set<String> = ["App/MercuryBrain.swift"]
    private static let mirrors: [String: String] = ["UI/SanctumViewModel.swift": "container.brain.visualState"]
    private static let sourceDirectories = ["App", "Core", "Memory", "Models", "Nexus", "Personas", "Services", "UI", "Intents"]

    /// `visualState = …` or `x.visualState = …`, but not `==`, and not a `visualState: VisualState = …` declaration.
    private static let assignment = try? NSRegularExpression(pattern: #"\bvisualState\s*=(?!=)\s*([^\n]*)"#)

    func testOnlyMercuryBrainAssignsVisualState() throws {
        let regex = try XCTUnwrap(Self.assignment)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        var ownerAssignments = 0
        for directory in Self.sourceDirectories {
            let base = root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let path = String(url.path.dropFirst(root.path.count + 1))
                let text = try String(contentsOf: url, encoding: .utf8)
                for (number, line) in text.components(separatedBy: "\n").enumerated() {
                    let code = line.components(separatedBy: "//").first ?? ""
                    let range = NSRange(code.startIndex..., in: code)
                    for match in regex.matches(in: code, range: range) {
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
        XCTAssertFalse(matches("var visualState: VisualState = .idle"))
    }
}
