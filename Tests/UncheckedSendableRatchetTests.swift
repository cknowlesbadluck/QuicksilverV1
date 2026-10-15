import Foundation
import XCTest

/// Issue #252 ratchet: `@unchecked Sendable` conformances are only allowed at the
/// declaration sites listed here. Adding a new one fails CI. Removing one means
/// shrinking the allowlist in the same PR.
final class UncheckedSendableRatchetTests: XCTestCase {
    /// LoggerService wraps `os.Logger` (not Sendable). Removal is tracked by #284 (owner-gated).
    private static let allowlist: Set<String> = ["Core/LoggerService.swift"]

    private static let sourceDirectories = [
        "App", "Core", "Memory", "Models", "Nexus", "Personas", "Services", "UI", "Intents"
    ]

    func testNoNewUncheckedSendableConformances() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var offenders: Set<String> = []
        for directory in Self.sourceDirectories {
            let base = root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                // Only conformances (": @unchecked Sendable" or ", @unchecked Sendable"), not comments.
                let declares = text.split(separator: "\n").contains { line in
                    let code = line.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
                    return code.contains(": @unchecked Sendable") || code.contains(", @unchecked Sendable")
                }
                if declares { offenders.insert(String(url.path.dropFirst(root.path.count + 1))) }
            }
        }
        let unexpected = offenders.subtracting(Self.allowlist)
        XCTAssertTrue(unexpected.isEmpty, "New @unchecked Sendable (issue #252): \(unexpected.sorted())")
        let stale = Self.allowlist.subtracting(offenders)
        XCTAssertTrue(stale.isEmpty, "Remove from allowlist, conformance is gone: \(stale.sorted())")
    }
}
