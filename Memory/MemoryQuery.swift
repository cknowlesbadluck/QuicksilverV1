import Foundation
import Core

/// Simple, testable query surface over memory items.
/// No vector search, no cloud. Pure filtering + ranking.
public struct MemoryQuery: Sendable {

    public var category: MemoryItem.Category?
    public var personaScope: String?
    public var minimumImportance: Double?
    public var keyPrefix: String?
    public var text: String?
    public var limit: Int?

    public init(
        category: MemoryItem.Category? = nil,
        personaScope: String? = nil,
        minimumImportance: Double? = nil,
        keyPrefix: String? = nil,
        text: String? = nil,
        limit: Int? = nil
    ) {
        self.category = category
        self.personaScope = personaScope
        self.minimumImportance = minimumImportance
        self.keyPrefix = keyPrefix
        self.text = text
        self.limit = limit
    }

    /// Apply the query to an in-memory collection. Deterministic and pure.
    public func apply(to items: [MemoryItem], now: Date = Date()) -> [MemoryItem] {
        var result = items

        if let category {
            result = result.filter { $0.category == category }
        }
        if let personaScope {
            result = result.filter { $0.personaScope == nil || $0.personaScope == personaScope }
        }
        if let minimumImportance {
            result = result.filter { $0.importance >= minimumImportance }
        }
        if let keyPrefix {
            result = result.filter { $0.key.hasPrefix(keyPrefix) }
        }

        let tokens = Self.tokens(from: text)
        if tokens.isEmpty {
            result.sort {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.updatedAt > $1.updatedAt
            }
        } else {
            result = result.filter { Self.overlap($0, tokens: tokens) > 0 }
            result.sort {
                let left = Self.rank($0, tokens: tokens, now: now)
                let right = Self.rank($1, tokens: tokens, now: now)
                if left != right { return left > right }
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.updatedAt > $1.updatedAt
            }
        }

        if let limit, limit > 0 {
            result = Array(result.prefix(limit))
        }

        return result
    }

    /// On-device token overlap. Zero means the item does not match the user text.
    static func overlap(_ item: MemoryItem, tokens: [String]) -> Double {
        guard !tokens.isEmpty else { return 0 }
        let haystack = (item.key + " " + item.value).lowercased()
        let hits = tokens.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
        return Double(hits) / Double(tokens.count)
    }

    static func rank(_ item: MemoryItem, tokens: [String], now: Date) -> Double {
        let overlap = overlap(item, tokens: tokens)
        guard overlap > 0 else { return 0 }
        let decayed = MemoryScorer.decayedImportance(for: item, now: now)
        return overlap * 0.7 + decayed * 0.3
    }

    static func tokens(from text: String?) -> [String] {
        guard let text else { return [] }
        let parts = text.lowercased().split { !$0.isLetter && !$0.isNumber }
        var seen = Set<String>()
        return parts.compactMap { part in
            let token = String(part)
            guard token.count >= 2, seen.insert(token).inserted else { return nil }
            return token
        }
    }
}
