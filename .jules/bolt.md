# Performance Learnings - Quicksilver / Mercury

## N+1 Batch Deletion in Memory Management
- **Issue:** Iterating over items and executing individual asynchronous actor deletes (`store.delete(id:)`) in a loop caused N+1 persistence overhead (separate disk reads/writes in `UserDefaults` and separate fetch/context save transactions in `SwiftData`).
- **Solution:** Introduced `delete(ids: Set<UUID>)` on `MemoryStore` protocol (with a protocol extension fallback) and implemented optimized batch deletion across `InMemoryMemoryStore`, `UserDefaultsMemoryStore`, and `SwiftDataMemoryStore`. Refactored `MemoryManager.pruneBelow(importance:)` and `MemoryManager.clearAll()` to issue a single batch deletion.
- **Impact:** Reduced persistence calls during memory pruning and clear operations from O(N) disk writes/transactions to O(1) single batch operation.
