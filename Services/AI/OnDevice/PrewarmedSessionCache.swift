import Foundation
import Synchronization

/// M3.5-T4 follow-up: holds at most one warmed, **unused** on-device session,
/// keyed by its exact instructions.
///
/// - `take(for:)` hands the session over only when the instructions match exactly.
///   An aspect or system-prompt change is a key mismatch, so the stale session is
///   dropped and the caller builds a fresh one.
/// - Sessions are single-use. The Brain sends the whole transcript each turn, so a
///   reused session would also carry the previous turn's transcript (a
///   context-leak and double-history risk). After a turn, the caller warms a
///   *new* session for the next one.
/// - `discard()` drops the session, for memory pressure, AI switched off, or
///   history cleared.
public final class PrewarmedSessionCache<Session: Sendable>: Sendable {
    private struct Entry: Sendable {
        let key: String
        let session: Session
    }

    private let slot = Mutex<Entry?>(nil)

    public init() {}

    /// Normalises nil and empty instructions to one key.
    public static func key(for instructions: String?) -> String { instructions ?? "" }

    /// Stores a freshly warmed session, replacing any previous one.
    public func store(_ session: Session, for instructions: String?) {
        slot.withLock { $0 = Entry(key: Self.key(for: instructions), session: session) }
    }

    /// Takes the warmed session if its instructions match. Mismatch or empty returns nil.
    /// A taken session is removed either way: never handed out twice.
    public func take(for instructions: String?) -> Session? {
        slot.withLock { entry in
            defer { entry = nil }
            guard let current = entry, current.key == Self.key(for: instructions) else { return nil }
            return current.session
        }
    }

    public func discard() { slot.withLock { $0 = nil } }

    public var isWarm: Bool { slot.withLock { $0 != nil } }
}
