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
            let lexical = retrieveSnapshot(limit: limit, text: query)
            return MemoryQuery.excludingHistoryContents(lexical, historyContents: historyContents)
        }
        let pool = MemoryQuery.excludingHistoryContents(
            retrieveSnapshot(limit: 48, text: nil),
            historyContents: historyContents
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
            let lexical = retrieveSnapshot(limit: limit, text: query)
            return MemoryQuery.excludingHistoryContents(lexical, historyContents: historyContents)
        }
    }

    /// Keeps the on-device vector sidecar aligned with MemoryManager via `memoryDidUpdate`.
    /// Call after the initial `memoryManager.load()` so the first rebuild sees persisted items.
    func startMemoryIndexSync() {
        guard let memoryIndex else { return }
        memoryIndexSyncTask?.cancel()
        memoryIndexSyncTask = Task { [weak self] in
            guard let self else { return }
            let stream = await eventBus.events(bufferingNewest: 16) { event in
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
