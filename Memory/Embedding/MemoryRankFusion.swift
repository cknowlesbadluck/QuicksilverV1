import Foundation
import Core

/// Fuses lexical overlap with on-device cosine hits.
///
/// Lexical ranking stays the floor. A vector hit can surface a note that shares
/// no tokens with the question, but only above `vectorFloor`, so a weak cosine
/// cannot drag an unrelated memory into the cloud payload.
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
            let lexical = tokens.isEmpty ? 0 : MemoryQuery.rank(item, tokens: tokens, now: now)
            let cosine = vectors[item.id] ?? 0
            let vector = cosine >= vectorFloor ? cosine : 0
            let score: Double
            if vector > 0 && lexical > 0 {
                score = lexical * 0.4 + vector * 0.6
            } else if vector > 0 {
                score = vector
            } else {
                score = lexical
            }
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
