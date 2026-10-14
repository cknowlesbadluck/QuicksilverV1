import Foundation

/// Persists the entity's active aspect and when it last changed, so dwell and
/// continuity survive relaunch (priority 3). Stores two scalars only; no content.
/// Not `Sendable`: owned by the `@MainActor` Brain.
public struct AspectContinuityStore {
    private let defaults: UserDefaults
    private let aspectKey: String
    private let changedAtKey: String

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "mercury.aspect") {
        self.defaults = defaults
        self.aspectKey = "\(keyPrefix).active"
        self.changedAtKey = "\(keyPrefix).lastChangedAt"
    }

    public struct Snapshot: Equatable, Sendable {
        public let aspect: Aspect
        public let lastChangedAt: Date?
    }

    public func load() -> Snapshot? {
        guard let raw = defaults.string(forKey: aspectKey), let aspect = Aspect(rawValue: raw) else { return nil }
        let stamp = defaults.object(forKey: changedAtKey) as? Double
        return Snapshot(aspect: aspect, lastChangedAt: stamp.map(Date.init(timeIntervalSince1970:)))
    }

    public func save(_ aspect: Aspect, changedAt: Date) {
        defaults.set(aspect.rawValue, forKey: aspectKey)
        defaults.set(changedAt.timeIntervalSince1970, forKey: changedAtKey)
    }

    public func clear() {
        defaults.removeObject(forKey: aspectKey)
        defaults.removeObject(forKey: changedAtKey)
    }
}
