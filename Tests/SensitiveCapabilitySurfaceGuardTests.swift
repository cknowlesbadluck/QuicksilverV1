import Foundation
import XCTest

/// Quicksilver reads no clipboard, location, contacts, calendar, photos, camera, microphone or
/// health data today. Any of these needs a privacy-manifest and usage-string review, so a file
/// that starts using one fails here until it is reviewed and added to `allowed`.
final class SensitiveCapabilitySurfaceGuardTests: XCTestCase {
    static let allowed: Set<String> = []
    static let sourceDirectories = ["App", "Core", "Intents", "Memory", "Models", "Nexus", "Personas", "Services", "UI"]
    static let pattern = #"\b(UIPasteboard|NSPasteboard|CLLocationManager|CNContactStore|EKEventStore|PHPhotoLibrary|AVCaptureDevice|AVAudioRecorder|HKHealthStore)\b|\bimport\s+(?:\w+\s+)?(CoreLocation|Contacts|EventKit|Photos|HealthKit)\b"#

    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Reuses the reviewed Swift-aware scanner (comments and string text removed).
    static func usesCapability(_ text: String) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let code = FoundationModelsSurfaceGuardTests.codeOnly(text)
        return regex.firstMatch(in: code, range: NSRange(code.startIndex..., in: code)) != nil
    }

    func testNoUnreviewedSensitiveCapability() throws {
        var offenders: [String] = []
        var seen: Set<String> = []
        for directory in Self.sourceDirectories {
            let base = Self.root.appendingPathComponent(directory)
            var isDirectory: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: base.path, isDirectory: &isDirectory) && isDirectory.boolValue,
                          "required source directory \(directory) is missing; update sourceDirectories")
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let path = String(url.path.dropFirst(Self.root.path.count + 1))
                guard try Self.usesCapability(String(contentsOf: url, encoding: .utf8)) else { continue }
                seen.insert(path)
                if !Self.allowed.contains(path) { offenders.append(path) }
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "sensitive capability without privacy review (see allowed)")
        XCTAssertEqual(Self.allowed.subtracting(seen).sorted(), [], "allowlist has files that no longer use the capability")
    }

    func testPatternCatchesCodeAndIgnoresCommentsAndStrings() throws {
        XCTAssertTrue(try Self.usesCapability("let text = UIPasteboard.general.string"))
        XCTAssertTrue(try Self.usesCapability("import CoreLocation"))
        XCTAssertTrue(try Self.usesCapability("@preconcurrency import Contacts"))
        XCTAssertTrue(try Self.usesCapability("let store = EKEventStore()"))
        XCTAssertTrue(try Self.usesCapability("AVCaptureDevice.requestAccess(for: .video) { _ in }"))
        XCTAssertFalse(try Self.usesCapability("// UIPasteboard is not used"))
        XCTAssertFalse(try Self.usesCapability("let label = \"HKHealthStore\""))
        XCTAssertFalse(try Self.usesCapability("import ContactsUIish"))
    }
}
