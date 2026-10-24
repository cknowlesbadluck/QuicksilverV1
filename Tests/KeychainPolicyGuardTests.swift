import XCTest

/// Source-scan guard for the privacy floor (roadmap phase 3): Keychain items stay on this device.
/// Fails if production code uses a Keychain accessibility class that isn't `…ThisDeviceOnly`,
/// opts into iCloud Keychain sync, or writes Keychain items outside `KeychainStore`.
final class KeychainPolicyGuardTests: XCTestCase {
    private static let productionDirectories = [
        "App", "Core", "Services", "Nexus", "Memory", "Intents", "UI", "Personas", "Models"
    ]
    private static let keychainStore = "Core/KeychainStore.swift"

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func testKeychainItemsStayOnThisDevice() throws {
        let accessibility = try NSRegularExpression(pattern: #"\bkSecAttrAccessible[A-Za-z]+\b"#)
        let synchronizable = try NSRegularExpression(pattern: #"\bkSecAttrSynchronizable\b"#)
        let writes = try NSRegularExpression(pattern: #"\bSecItem(Add|Update)\s*\("#)
        var violations: [String] = []
        var scanned = 0
        for (relative, source) in try productionSources() {
            scanned += 1
            let range = NSRange(source.startIndex..., in: source)
            for match in accessibility.matches(in: source, range: range) {
                let token = (source as NSString).substring(with: match.range)
                if !token.hasSuffix("ThisDeviceOnly") {
                    violations.append("\(relative): \(token) can leave this device")
                }
            }
            if synchronizable.firstMatch(in: source, range: range) != nil {
                violations.append("\(relative): kSecAttrSynchronizable (iCloud Keychain sync)")
            }
            if relative != Self.keychainStore, writes.firstMatch(in: source, range: range) != nil {
                violations.append("\(relative): Keychain write outside KeychainStore")
            }
        }
        XCTAssertGreaterThan(scanned, 50, "scan found too few production files; is the repo root right?")
        XCTAssertEqual(violations, [], violations.joined(separator: "\n"))
    }

    func testKeychainStorePinsThisDeviceOnlyAccessibility() throws {
        let url = repoRoot.appendingPathComponent(Self.keychainStore)
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            source.contains("kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"),
            "KeychainStore must set AfterFirstUnlockThisDeviceOnly on every write"
        )
    }

    private func productionSources() throws -> [(String, String)] {
        var result: [(String, String)] = []
        for dir in Self.productionDirectories {
            let base = repoRoot.appendingPathComponent(dir)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = String(url.path.dropFirst(repoRoot.path.count + 1))
                result.append((relative, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        return result
    }
}
