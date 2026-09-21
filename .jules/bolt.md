# Bolt Performance Learnings — Quicksilver

## SwiftData Batch Operations

### N+1 Query in SwiftData Deletions
- **Problem**: Querying SwiftData models via `context.fetch(descriptor)` and looping over the results calling `context.delete(entry)` creates an N+1 query and memory bottleneck. Each matching model is faulted into memory, instantiated, tracked in the context object graph, and deleted row-by-row.
- **Solution**: Use SwiftData's native batch deletion API: `try context.delete(model: T.self, where: #Predicate { ... })`.
- **Impact**: Executes a single direct store delete query (SQL `DELETE FROM ... WHERE ...`), bypassing object instantiation and memory allocations for matching entities.
- **Scope**: Applied to `SwiftDataMemoryStore.delete(id:)` and `SwiftDataMemoryStore.deleteAll(in:)`.
