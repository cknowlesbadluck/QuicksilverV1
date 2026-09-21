import Foundation

/// Application-wide configuration.
/// Static values today. Future: load from UserDefaults, remote config, or encrypted storage.
public struct AppConfiguration: Sendable {
    public static let shared = AppConfiguration()

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
        version: String = "0.2.0",
        build: String = "7",
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

    public var fullVersionString: String {
        "\(version) (\(build))"
    }
}
