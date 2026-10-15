import XCTest

/// Privacy / SideStore hardening tripwires over the shipped app's inputs
/// (project.yml Info.plist keys, bundled Resources, privacy manifest, app sources).
final class BundleHardeningTests: XCTestCase {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func read(_ relative: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Secret-shaped values: Google, OpenAI-style, GitHub, Slack, AWS keys, bearer literals.
    static let secretPattern = [
        #"AIza[0-9A-Za-z_-]{20,}"#, #"sk-[A-Za-z0-9_-]{20,}"#, #"gh[pousr]_[A-Za-z0-9]{20,}"#,
        #"xox[abpr]-[A-Za-z0-9-]{10,}"#, #"AKIA[0-9A-Z]{16}"#, #"Bearer [A-Za-z0-9._-]{20,}"#
    ].joined(separator: "|")

    func testNoATSRelaxation() throws {
        let project = try read("project.yml")
        for key in ["NSAllowsArbitraryLoads", "NSExceptionAllowsInsecureHTTPLoads", "NSAllowsLocalNetworking"] {
            XCTAssertFalse(project.contains(key), "ATS relaxation \(key) in project.yml")
        }
    }

    func testNoSecretsInInfoPlistKeysOrBundledResources() throws {
        var texts: [(String, String)] = [("project.yml", try read("project.yml"))]
        let resources = Self.repoRoot.appendingPathComponent("Resources")
        if let walker = FileManager.default.enumerator(at: resources, includingPropertiesForKeys: nil) {
            for case let url as URL in walker where ["json", "txt", "plist", "strings", "md"].contains(url.pathExtension) {
                texts.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        let offenders = texts.filter { $0.1.range(of: Self.secretPattern, options: .regularExpression) != nil }.map(\.0)
        XCTAssertEqual(offenders, [], "Secret-shaped value shipped in the bundle")
    }

    func testPrivacyManifestDeclaresNoTracking() throws {
        let manifest = try read("PrivacyInfo.xcprivacy")
        let compact = manifest.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        XCTAssertTrue(compact.contains("<key>NSPrivacyTracking</key><false/>"))
        XCTAssertTrue(compact.contains("<key>NSPrivacyTrackingDomains</key><array/>"))
    }

    /// The app target compiles App/UI/Models/Resources only: no test sources ship in the IPA.
    func testAppTargetExcludesTestSources() throws {
        let project = try read("project.yml")
        guard let start = project.range(of: "  Quicksilver:\n"),
              let end = project.range(of: "\n  QuicksilverTests:", range: start.upperBound..<project.endIndex) else {
            return XCTFail("Quicksilver app target not found in project.yml")
        }
        let appTarget = project[start.upperBound..<end.lowerBound]
        for testDir in ["- path: Tests", "- path: AppTests", "- path: UITests"] {
            XCTAssertFalse(appTarget.contains(testDir), "App target includes \(testDir)")
        }
    }

    /// Shipped code talks to the network over HTTPS only.
    func testNoPlainHTTPURLsInShippedSources() throws {
        var offenders: [String] = []
        for directory in ["App", "UI", "Core", "Services", "Nexus", "Memory", "Personas", "Intents"] {
            let base = Self.repoRoot.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                if text.range(of: #""http://(?!localhost|127\.0\.0\.1)"#, options: .regularExpression) != nil {
                    offenders.append(url.lastPathComponent)
                }
            }
        }
        XCTAssertEqual(offenders, [], "Plain-HTTP URL literal in shipped code")
    }
}
