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

    /// Drops items whose value matches a chat turn already carried in conversation history,
    /// so Ask does not double-send the same text as both history and retrieved memory.
    public static func excludingHistoryContents(
        _ items: [MemoryItem],
        historyContents: [String]
    ) -> [MemoryItem] {
        let excluded = Set(
            historyContents
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        guard !excluded.isEmpty else { return items }
        return items.filter {
            !excluded.contains($0.value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// On-device token overlap. Zero means the item does not match the user text.
    static func overlap(_ item: MemoryItem, tokens: [String]) -> Double {
        guard !tokens.isEmpty else { return 0 }
        let haystack = (item.key + " " + item.value).lowercased()
        let hits = tokens.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
        return Double(hits) / Double(tokens.count)
    }

    /// Lexical rank used when no embedder is available: overlap × decayed importance.
    static func rank(_ item: MemoryItem, tokens: [String], now: Date) -> Double {
        relevanceScore(item: item, cosine: nil, tokens: tokens, now: now)
    }

    /// Shared Ask score: cosine × decayedImportance when cosine is present,
    /// otherwise term-overlap × decayedImportance.
    public static func relevanceScore(
        item: MemoryItem,
        cosine: Double?,
        tokens: [String],
        now: Date
    ) -> Double {
        let similarity: Double
        if let cosine, cosine > 0 {
            similarity = cosine
        } else {
            similarity = overlap(item, tokens: tokens)
        }
        guard similarity > 0 else { return 0 }
        return similarity * MemoryScorer.decayedImportance(for: item, now: now)
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
