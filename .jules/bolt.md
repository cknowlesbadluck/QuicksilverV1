## Performance Optimization Insights

- **Avoid array re-allocation in filter closures**: Hoist static array/set filtering targets into `private static let` set constants outside of hot filter loops. This prevents repeated heap allocations per element and changes collection lookup complexity from O(N) array search to O(1) hash lookup.
