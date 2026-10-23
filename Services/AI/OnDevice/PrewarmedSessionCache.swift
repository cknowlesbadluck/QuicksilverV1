import Foundation
import Synchronization

/// M3.5-T4 follow-up: holds a few warmed, **unused** on-device sessions, each keyed
/// by its exact instructions (default capacity 2: the chat turn and one side task such
/// as a note summary, so a summary no longer evicts the warmed chat session).
///
/// - `take(for:)` hands a session over only when the instructions match exactly, and
///   removes it. A mismatch returns nil and leaves the other warmed sessions alone; a
///   session is never handed out for different instructions (no stale aspect/system prompt).
/// - Sessions are single-use. The Brain sends the whole transcript each turn, so a
///   reused session would also carry the previous turn's transcript (a
///   context-leak and double-history risk). After a turn, the caller warms a
///   *new* session for the next one.
/// - `store` replaces a session with the same key and evicts the least recently stored
///   one beyond `capacity`.
/// - `discard()` drops every session, for memory pressure, AI switched off, or
///   history cleared.
public final class PrewarmedSessionCache<Session: Sendable>: Sendable {
    private struct Entry: Sendable {
        let key: String
        let session: Session
    }

    /// Oldest first.
    private let slots = Mutex<[Entry]>([])
    public let capacity: Int

    public init(capacity: Int = 2) {
        self.capacity = max(1, capacity)
    }

    /// Normalises nil and empty instructions to one key.
    public static func key(for instructions: String?) -> String { instructions ?? "" }

    /// Stores a freshly warmed session, replacing one with the same instructions and
    /// evicting the least recently stored beyond `capacity`.
    public func store(_ session: Session, for instructions: String?) {
        let key = Self.key(for: instructions)
        slots.withLock { entries in
            entries.removeAll { $0.key == key }
            entries.append(Entry(key: key, session: session))
            if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
        }
    }

    /// Takes the warmed session for exactly these instructions, or nil. A taken session
    /// is removed: never handed out twice. Other keys are left warm.
    public func take(for instructions: String?) -> Session? {
        let key = Self.key(for: instructions)
        return slots.withLock { entries in
            guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
            return entries.remove(at: index).session
        }
    }

    public func discard() { slots.withLock { $0.removeAll() } }

    public var isWarm: Bool { slots.withLock { !$0.isEmpty } }

    /// Number of warmed sessions held (at most `capacity`).
    public var count: Int { slots.withLock { $0.count } }

    /// True when a session for exactly these instructions is warm.
    public func isWarm(for instructions: String?) -> Bool {
        let key = Self.key(for: instructions)
        return slots.withLock { entries in entries.contains { $0.key == key } }
    }
}
