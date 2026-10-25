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

    /// Drops `/* */` and `//` comments so doc prose that mentions UserDefaults doesn't count.
    static func codeOnly(_ text: String) -> String {
        let noBlocks = text.replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: "", options: .regularExpression)
        return noBlocks.components(separatedBy: "\n").map { $0.components(separatedBy: "//").first ?? "" }.joined(separator: "\n")
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
    }
}
