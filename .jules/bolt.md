# Performance Learnings & Memory

## Lazy Evaluation in Collection Pipelines
- Adding `.lazy` before high-cost mapping (`map { $0.trimmingCharacters(...) }`) and filtering (`filter { !$0.isEmpty }`) operations when taking a limited prefix (`prefix(N)`) avoids eager allocation of intermediate arrays and prevents processing elements beyond the required limit.
- Inline code comments should be included to explain the performance motivation when utilizing lazy collection evaluation.
