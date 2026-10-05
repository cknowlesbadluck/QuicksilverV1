import Foundation
import Core
import Memory

extension MercuryBrain {
    /// Ask-path ranking. Score is cosine × decayedImportance when the embedder
    /// is loaded; term-overlap × decayedImportance otherwise. Chat turns already
    /// present in conversation history are dropped so they are not double-sent.
    func rankedMemories(
        for query: String,
        limit: Int,
        excludingHistory history: [Message] = []
    ) async -> [MemoryItem] {
        let historyContents = history.map(\.content)
        guard let memoryIndex else {
            return lexicalMemories(for: query, limit: limit, excluding: historyContents)
        }
        // Exclude history first, then cap the vector pool so history turns cannot
        // crowd out eligible notes under the 48-candidate search budget.
        let pool = Array(
            MemoryQuery.excludingHistoryContents(
                retrieveSnapshot(limit: 96, text: nil),
                historyContents: historyContents
            ).prefix(48)
        )
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
            return lexicalMemories(for: query, limit: limit, excluding: historyContents)
        }
    }

    /// Over-fetches, drops history matches, then applies `limit` so excluded turns
    /// do not consume ranked slots.
    private func lexicalMemories(
        for query: String,
        limit: Int,
        excluding historyContents: [String]
    ) -> [MemoryItem] {
        guard limit > 0 else { return [] }
        let overFetch = max(limit * 4, 24)
        let eligible = MemoryQuery.excludingHistoryContents(
            retrieveSnapshot(limit: overFetch, text: query),
            historyContents: historyContents
        )
        return Array(eligible.prefix(limit))
    }

    /// Keeps the on-device vector sidecar aligned with MemoryManager via `memoryDidUpdate`.
    /// Call after the initial `memoryManager.load()` so the first rebuild sees persisted items.
    func startMemoryIndexSync() {
        guard let memoryIndex else { return }
        memoryIndexSyncTask?.cancel()
        memoryIndexSyncTask = Task { [weak self] in
            guard let self else { return }
            // Register first so updates during rebuild are buffered. Use a large
            // newest-buffer so a busy import/clear cannot drop IDs before apply.
            let stream = await eventBus.events(bufferingNewest: 512) { event in
                if case .memoryDidUpdate = event { return true }
                return false
            }
            await memoryIndex.rebuild(from: memoryManager.items)
            for await event in stream {
                guard !Task.isCancelled else { break }
                guard case .memoryDidUpdate(let itemID) = event,
                      let id = UUID(uuidString: itemID) else { continue }
                if let item = memoryManager.items.first(where: { $0.id == id }) {
                    await memoryIndex.upsert(item)
                } else {
                    await memoryIndex.remove(id: id)
                }
            }
        }
    }
}
