import Foundation
import Observation

/// Central feature flag surface with a one-time migration for architectural defaults.
@MainActor
@Observable
public final class FeatureFlags {
    public private(set) var flags: [String: Bool]

    private let defaults: UserDefaults
    private let storageKey = "quicksilver.featureFlags"
    private let schemaKey = "quicksilver.featureFlags.schema"
    private static let currentSchema = 2

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let saved = defaults.dictionary(forKey: storageKey) as? [String: Bool]
        var resolved = saved ?? Self.defaultFlags
        let schema = defaults.integer(forKey: schemaKey)

        // v2 makes Brain-owned aspect selection authoritative. Existing installs
        // must not silently retain the old autonomous persona behavior.
        if schema < 2 {
            resolved["personaAutonomy"] = false
            defaults.set(Self.currentSchema, forKey: schemaKey)
        }

        self.flags = resolved
        if saved == nil {
            defaults.set(Self.defaultFlags, forKey: storageKey)
        } else if schema < 2 {
            defaults.set(resolved, forKey: storageKey)
        }
    }

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
        defaults.set(Self.currentSchema, forKey: schemaKey)
    }

    public func resetToDefaults() {
        flags = Self.defaultFlags
        defaults.set(flags, forKey: storageKey)
        defaults.set(Self.currentSchema, forKey: schemaKey)
    }
}
