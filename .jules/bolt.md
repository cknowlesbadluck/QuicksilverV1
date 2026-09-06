## 2026-09-06 - Single-Pass Collection Filtering in Memory Queries
**Learning:** Chaining multiple `.filter` calls on Swift Array collections creates intermediate array allocations for each stage (up to 4 allocations in `MemoryQuery`). Consolidating predicate conditions into a single-pass `filter` closure eliminates allocations and reduces iteration overhead while preserving query semantics.
**Action:** Always combine sequential array filters into a single-pass predicate or lazy sequence evaluation when executing memory/cache queries in high-frequency paths.
