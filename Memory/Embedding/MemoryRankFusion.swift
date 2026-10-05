import Foundation
import Core

/// Ranks memories for Ask by relevance × decayed importance (M3-T14).
///
/// When a cosine hit clears `vectorFloor`, score = cosine × `decayedImportance`.
/// Otherwise score = term-overlap × `decayedImportance` (the no-embedder path).
/// Weak cosine cannot surface an unrelated note; decay keeps stale hits from
/// crowding fresher ones with the same similarity.
public enum MemoryRankFusion {
    /// Cosine below this is treated as no match. 0.22 is above noise for the
    /// short on-device embeddings used by `EmbeddingIndex` and below typical
    /// same-topic scores in the fusion tests.
    public static let vectorFloor = 0.22

    public static func fuse(
        pool: [MemoryItem],
        vectorMatches: [EmbeddingIndex.Match],
        text: String,
        limit: Int,
        now: Date = Date()
    ) -> [MemoryItem] {
        guard limit > 0 else { return [] }
        let tokens = MemoryQuery.tokens(from: text)
        guard !tokens.isEmpty || !vectorMatches.isEmpty else { return [] }

        let vectors = Dictionary(uniqueKeysWithValues: vectorMatches.map { ($0.id, $0.score) })

        var ranked: [(item: MemoryItem, score: Double)] = []
        for item in pool {
            let cosine = vectors[item.id] ?? 0
            let score = MemoryQuery.relevanceScore(
                item: item,
                cosine: cosine >= Self.vectorFloor ? cosine : nil,
                tokens: tokens,
                now: now
            )
            guard score > 0 else { continue }
            ranked.append((item, score))
        }

        ranked.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.item.importance != rhs.item.importance {
                return lhs.item.importance > rhs.item.importance
            }
            if lhs.item.updatedAt != rhs.item.updatedAt {
                return lhs.item.updatedAt > rhs.item.updatedAt
            }
            return lhs.item.id.uuidString < rhs.item.id.uuidString
        }

        return ranked.prefix(limit).map(\.item)
    }
}
