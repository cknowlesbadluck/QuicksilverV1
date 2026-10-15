import Foundation
import Core

/// M4-T4: bounded memory growth with a conservative, test-proven policy.
///
/// **Only conversation turns (`.conversation`) are ever pruned automatically.**
/// User notes (`remember`, currently stored as `.temporary` with
/// `source: mercury-brain`), preferences, projects and system items are never
/// touched. Only the user deletes those, from the Memory view.
///
/// Defaults:
/// - `maxConversationAge`: 90 days. Older turns are removed.
/// - `maxConversationItems`: 1,000. Above this, the oldest turns go first.
public struct MemoryRetentionPolicy: Sendable, Equatable {
    public var maxConversationAge: TimeInterval
    public var maxConversationItems: Int

    public init(maxConversationAge: TimeInterval = 90 * 24 * 60 * 60, maxConversationItems: Int = 1_000) {
        self.maxConversationAge = maxConversationAge
        self.maxConversationItems = max(0, maxConversationItems)
    }

    public static let `default` = MemoryRetentionPolicy()

    /// True only for items this policy may ever remove.
    public static func isPrunable(_ item: MemoryItem) -> Bool {
        item.category == .conversation && item.metadata["source"] != "user"
    }

    /// Items to remove at `now`: expired turns first, then the oldest turns above the cap.
    public func victims(in items: [MemoryItem], now: Date) -> [MemoryItem] {
        let turns = items.filter(Self.isPrunable).sorted { $0.updatedAt < $1.updatedAt }
        let cutoff = now.addingTimeInterval(-maxConversationAge)
        let expired = turns.filter { $0.updatedAt < cutoff }
        let survivors = turns.filter { $0.updatedAt >= cutoff }
        let overflow = survivors.prefix(max(0, survivors.count - maxConversationItems))
        return expired + overflow
    }
}
