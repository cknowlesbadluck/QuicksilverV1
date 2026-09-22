import Foundation
import Observation

/// Central feature flag surface.
/// Day Two: in-memory + simple UserDefaults persistence.
/// Future: remote config without locking the app to a specific backend.
@MainActor
@Observable
public final class FeatureFlags {
    public private(set) var flags: [String: Bool]

    private let defaults: UserDefaults
    private let storageKey = "quicksilver.featureFlags"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.dictionary(forKey: storageKey) as? [String: Bool] {
            self.flags = saved
        } else {
            self.flags = Self.defaultFlags
        }
    }

    /// Defaults: Brain owns aspect selection. PersonaManager autonomy is off.
    /// Explicit diagnostics override remains available via switchTo.
    private static let defaultFlags: [String: Bool] = [
        "personaSwitching": true,
        "personaAutonomy": false,
        "memoryPersistence": true,
        "aiServiceEnabled": false,
        "nexusDetailedMetrics": false,
        "experimentalEventBus": true
    ]

    public func isEnabled(_ key: String) -> Bool {
        flags[key] ?? false
    }

    public func set(_ key: String, enabled: Bool) {
        flags[key] = enabled
        defaults.set(flags, forKey: storageKey)
    }

    public func resetToDefaults() {
        flags = Self.defaultFlags
        defaults.set(flags, forKey: storageKey)
    }
}
