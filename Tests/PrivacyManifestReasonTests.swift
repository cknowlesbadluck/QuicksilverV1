import Foundation
import XCTest

/// Required-reason APIs used in shipped code must be declared in PrivacyInfo.xcprivacy
/// with the reason that matches the use (Apple TN: "Describing use of required reason API").
final class PrivacyManifestReasonTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let shippedDirectories = ["App", "Core", "Intents", "Memory", "Nexus", "Personas", "Services", "UI"]

    /// Category → (code pattern, reasons that must be declared when the pattern appears).
    private static let rules: [(category: String, pattern: String, reasons: [String])] = [
        ("NSPrivacyAccessedAPICategoryUserDefaults", #"\bUserDefaults\b"#, ["CA92.1"]),
        // StorageMonitor reads free/total space; InsightEngine shows "Only N GB free." to the user.
        ("NSPrivacyAccessedAPICategoryDiskSpace", #"\.systemFreeSize\b|\.systemSize\b|volumeAvailableCapacity"#, ["85F4.1"]),
        ("NSPrivacyAccessedAPICategorySystemBootTime", #"\bsystemUptime\b|mach_absolute_time"#, []),
        ("NSPrivacyAccessedAPICategoryFileTimestamp", #"\.(creationDate|modificationDate|contentModificationDate)\b"#, [])
    ]

    private func manifestReasons() throws -> [String: Set<String>] {
        let data = try Data(contentsOf: Self.root.appendingPathComponent("PrivacyInfo.xcprivacy"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let types = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        var result: [String: Set<String>] = [:]
        for entry in types {
            let category = try XCTUnwrap(entry["NSPrivacyAccessedAPIType"] as? String)
            result[category, default: []].formUnion(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [])
        }
        return result
    }

    private func shippedCode() throws -> String {
        var text = ""
        for directory in Self.shippedDirectories {
            let base = Self.root.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                text += FoundationModelsSurfaceGuardTests.codeOnly(try String(contentsOf: url, encoding: .utf8)) + "\n"
            }
        }
        return text
    }

    func testUsedRequiredReasonAPIsAreDeclaredWithMatchingReasons() throws {
        let declared = try manifestReasons()
        let code = try shippedCode()
        for rule in Self.rules where code.range(of: rule.pattern, options: .regularExpression) != nil {
            let reasons = declared[rule.category]
            XCTAssertNotNil(reasons, "\(rule.category) API used in shipped code but not declared")
            for reason in rule.reasons {
                XCTAssertTrue(reasons?.contains(reason) == true, "\(rule.category) needs reason \(reason)")
            }
        }
    }

    func testEveryDeclaredCategoryHasAtLeastOneReason() throws {
        for (category, reasons) in try manifestReasons() {
            XCTAssertFalse(reasons.isEmpty, "\(category) declared without a reason")
        }
    }
}
