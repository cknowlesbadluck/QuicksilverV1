import Foundation

/// Application-wide configuration.
/// Static values today. Future: load from UserDefaults, remote config, or encrypted storage.
public struct AppConfiguration: Sendable {
    /// Fallbacks used when no bundle metadata exists (SPM tests, previews).
    /// Kept equal to project.yml by `LogPrivacyGuardTests.testVersionAlignment`.
    public static let fallbackVersion = "0.2.0"
    public static let fallbackBuild = "7"

    /// The app reads its version from the built Info.plist, so project.yml
    /// (MARKETING_VERSION / CURRENT_PROJECT_VERSION) is the single source at runtime.
    public static let shared = AppConfiguration(infoDictionary: Bundle.main.infoDictionary)

    public let appName: String
    public let version: String
    public let build: String
    /// Minimum OS the binary is *built* against (CI / Xcode 16 floor).
    /// The primary validation device runs a newer OS; a lower deployment target is intentional
    /// so SideStore IPAs can still be produced on current GitHub runners.
    public let minimumOSVersion: String
    /// Primary device target the project is designed and validated for.
    public let primaryDeviceOSVersion: String
    public let privacyPolicyURL: URL?
    public let supportEmail: String

    public init(
        appName: String = "Quicksilver",
        version: String = AppConfiguration.fallbackVersion,
        build: String = AppConfiguration.fallbackBuild,
        minimumOSVersion: String = "18.0",
        primaryDeviceOSVersion: String = "27.0",
        privacyPolicyURL: URL? = nil,
        supportEmail: String = "support@quicksilver.local"
    ) {
        self.appName = appName
        self.version = version
        self.build = build
        self.minimumOSVersion = minimumOSVersion
        self.primaryDeviceOSVersion = primaryDeviceOSVersion
        self.privacyPolicyURL = privacyPolicyURL
        self.supportEmail = supportEmail
    }

    /// Builds a configuration from bundle metadata. A missing, non-string,
    /// or blank value falls back to the compiled-in default. It never crashes.
    public init(infoDictionary: [String: Any]?) {
        func value(_ key: String) -> String? {
            guard let raw = infoDictionary?[key] as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        self.init(
            version: value("CFBundleShortVersionString") ?? Self.fallbackVersion,
            build: value("CFBundleVersion") ?? Self.fallbackBuild
        )
    }

    public var fullVersionString: String {
        "\(version) (\(build))"
    }
}
