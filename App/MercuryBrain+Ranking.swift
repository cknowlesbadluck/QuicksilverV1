import Foundation
import Core
import Memory

extension MercuryBrain {
    /// Ask-path ranking. Vector hits can surface a note with no shared tokens.
    /// Term-overlap fallback keeps the existing lexical query when no model is loaded.
    func rankedMemories(for query: String, limit: Int) async -> [MemoryItem] {
        guard let memoryIndex else {
            return retrieveSnapshot(limit: limit, text: query)
        }
        let pool = retrieveSnapshot(limit: 48, text: nil)
        let result = await memoryIndex.search(query, in: pool, limit: nil)
        switch result.method {
        case .vector:
            return MemoryRankFusion.fuse(
                pool: pool,
                vectorMatches: result.matches,
                text: query,
                limit: limit
            )
        case .termOverlap:
            return retrieveSnapshot(limit: limit, text: query)
        }
    }
}
