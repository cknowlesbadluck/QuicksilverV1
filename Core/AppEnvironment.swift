import Foundation

/// Runtime environment classification.
/// Used by FeatureFlags and services to alter behavior without hardcoding.
public enum AppEnvironment: String, Sendable, CaseIterable {
    case development
    case staging
    case production

    public static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}
