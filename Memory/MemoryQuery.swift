import Foundation
import Core

/// Simple, testable query surface over memory items.
/// No vector search, no cloud. Pure filtering + ranking.
public struct MemoryQuery: Sendable {

    public var category: MemoryItem.Category?
    public var personaScope: String?
    public var minimumImportance: Double?
    public var keyPrefix: String?
    public var limit: Int?

    public init(
        category: MemoryItem.Category? = nil,
        personaScope: String? = nil,
        minimumImportance: Double? = nil,
        keyPrefix: String? = nil,
        limit: Int? = nil
    ) {
        self.category = category
        self.personaScope = personaScope
        self.minimumImportance = minimumImportance
        self.keyPrefix = keyPrefix
        self.limit = limit
    }

    /// Apply the query to an in-memory collection. Deterministic and pure.
    /// Performance: Combines all predicates into a single-pass filter to eliminate
    /// up to 4 intermediate array allocations during query execution.
    public func apply(to items: [MemoryItem]) -> [MemoryItem] {
        var result = items.filter { item in
            if let category, item.category != category {
                return false
            }
            if let personaScope, let itemScope = item.personaScope, itemScope != personaScope {
                return false
            }
            if let minimumImportance, item.importance < minimumImportance {
                return false
            }
            if let keyPrefix, !item.key.hasPrefix(keyPrefix) {
                return false
            }
            return true
        }

        result.sort {
            if $0.importance != $1.importance { return $0.importance > $1.importance }
            return $0.updatedAt > $1.updatedAt
        }

        if let limit, limit > 0, result.count > limit {
            return Array(result.prefix(limit))
        }

        return result
    }
}
