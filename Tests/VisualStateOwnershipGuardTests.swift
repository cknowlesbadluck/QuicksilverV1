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
                let code = text.components(separatedBy: "\n")
                    .map { $0.components(separatedBy: "//").first ?? "" }
                    .joined(separator: "\n")
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
    }
}
