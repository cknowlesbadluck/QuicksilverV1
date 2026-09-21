# Performance Learnings & Optimizations

## MemoryManager.clearAll
- Avoid `for id in items.map(\.id)` which allocates a transient `Array<UUID>` on the heap prior to loop execution.
- Iterate directly `for item in items` and use `item.id` to eliminate O(N) heap allocations and mapping closure overhead.
